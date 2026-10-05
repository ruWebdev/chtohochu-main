import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// In-memory fake Laravel API для widget/unit-тестов.
///
/// Реализует контракт `/api/v1` на уровне [HttpClientAdapter]:
/// register/login/logout, `/me`, wishes CRUD. Для неизвестного
/// bearer-токена auto-vivify детерминированного пользователя —
/// как старый MockAuthRepository принимал `mock_token`.
///
/// Ошибки можно подмешивать через [failures]: `failures['POST /wishes']`
/// — код статуса или `DioExceptionType.connectionError`.
class FakeApiAdapter implements HttpClientAdapter {
  FakeApiAdapter({this.autoUserId});

  /// Если задан — неизвестный токен получает пользователя с этим id.
  /// Иначе генерируется детерминированный UUID из токена.
  final String? autoUserId;

  /// Сбои по ключу 'METHOD /path-prefix' → status code или 'network'.
  final Map<String, Object> failures = {};

  /// Одноразовые сбои: тот же формат, что [failures], но ключ
  /// снимается после первого совпадения — «единичный отказ»,
  /// повторный запрос проходит.
  final Map<String, Object> failuresOnce = {};

  /// Журнал запросов 'METHOD /path' — для assert'ов «что ушло на сервер».
  final List<String> requests = [];

  /// Пиковая параллельность обработки запросов — доказывает
  /// отсутствие параллельных sync-прогонов.
  int maxInFlight = 0;
  int _inFlight = 0;

  final _users = <String, Map<String, dynamic>>{}; // email → user
  final _passwords = <String, String>{}; // email → password
  final _tokens = <String, String>{}; // token → userId
  final _wishes =
      <String, Map<String, Map<String, dynamic>>>{}; // uid → id→wish
  /// uid → listId → list {'id','title',...,'items': {itemId: item}}.
  final _shoppingLists = <String, Map<String, Map<String, dynamic>>>{};

  /// uploadId → media upload {'user_id','object_key','status',...}.
  final _mediaUploads = <String, Map<String, dynamic>>{};

  /// `user_id|client_id` → uploadId — идемпотентность retry.
  final _mediaClientIndex = <String, String>{};

  /// Симметричные связи дружбы: uid → множество friendId.
  /// Backend хранит пару в одну строку — здесь храним обе стороны.
  final _friendships = <String, Set<String>>{};
  final _uuid = const Uuid();

  static const _uuidRe =
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

  Map<String, dynamic> _newUser(
    String email, {
    String? name,
    String? username,
  }) {
    return {
      'id': _uuid.v4(),
      'email': email,
      'name': name,
      'username': username,
      'avatar_url': null,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  String _userIdForToken(String? token) {
    if (token == null) throw _unauthorized();
    return _tokens.putIfAbsent(token, () {
      final email = 'user@chtohochu.ru';
      // Auto-vivified пользователь — как старый MockAuthRepository:
      // displayName/username из local-part email.
      final user = _users.putIfAbsent(email, () {
        final u = _newUser(email, name: 'user', username: 'user');
        if (autoUserId != null) u['id'] = autoUserId;
        return u;
      });
      _wishes.putIfAbsent(user['id'] as String, () => {});
      _shoppingLists.putIfAbsent(user['id'] as String, () => {});
      return user['id'] as String;
    });
  }

  DioException _unauthorized() => _error(401, 'Unauthenticated.');

  DioException _error(
    int code,
    String message, {
    Map<String, dynamic>? errors,
  }) {
    return DioException(
      requestOptions: RequestOptions(),
      response: Response(
        requestOptions: RequestOptions(),
        statusCode: code,
        data: {'message': message, 'errors': ?errors},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final method = options.method;
    final path = options.path; // baseUrl уже в uri — path = /api/v1/...
    requests.add('$method $path');
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      return await _handle(options, method, path, requestStream);
    } finally {
      _inFlight--;
    }
  }

  Future<ResponseBody> _handle(
    RequestOptions options,
    String method,
    String path,
    Stream<Uint8List>? requestStream,
  ) async {
    final body = requestStream == null
        ? null
        : jsonDecode(
                utf8.decode(
                  await requestStream
                      .expand((c) => [c])
                      .fold(<int>[], (a, b) => a..addAll(b)),
                ),
              )
              as Map<String, dynamic>;

    // Возможная инъекция сбоя.
    Object? failure;
    for (final entry in failures.entries) {
      final parts = entry.key.split(' ');
      if (method == parts[0] && path.startsWith(parts[1])) {
        failure = entry.value;
        break;
      }
    }
    if (failure == null) {
      for (final entry in failuresOnce.entries) {
        final parts = entry.key.split(' ');
        if (method == parts[0] && path.startsWith(parts[1])) {
          failure = entry.value;
          failuresOnce.remove(entry.key);
          break;
        }
      }
    }
    if (failure != null) {
      if (failure == 'network') {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      throw _error(failure as int, 'Injected failure.');
    }

    String? token;
    final auth = options.headers['authorization'] as String?;
    if (auth != null && auth.startsWith('Bearer ')) {
      token = auth.substring(7);
    }

    Map<String, dynamic>? data;
    int status = 200;

    if (path == '/auth/register' && method == 'POST') {
      final email = body!['email'] as String;
      if (_users.containsKey(email)) {
        throw _error(
          422,
          'The email has already been taken.',
          errors: {
            'email': ['The email has already been taken.'],
          },
        );
      }
      final user = _newUser(email, name: body['name'] as String?);
      _users[email] = user;
      _passwords[email] = body['password'] as String;
      final token2 = _uuid.v4();
      _tokens[token2] = user['id'] as String;
      _wishes.putIfAbsent(user['id'] as String, () => {});
      _shoppingLists.putIfAbsent(user['id'] as String, () => {});
      status = 201;
      data = {'token': token2, 'user': user};
    } else if (path == '/auth/login' && method == 'POST') {
      final email = body!['email'] as String;
      // Неизвестный email — auto-vivify (как старый mock, принимавший
      // любые креды); известный — проверка пароля.
      var user = _users[email];
      if (user != null && _passwords[email] != body['password']) {
        throw _error(401, 'Invalid credentials.');
      }
      user ??= _users[email] = _newUser(email);
      _passwords.putIfAbsent(email, () => body['password'] as String);
      _wishes.putIfAbsent(user['id'] as String, () => {});
      _shoppingLists.putIfAbsent(user['id'] as String, () => {});
      final token2 = _uuid.v4();
      _tokens[token2] = user['id'] as String;
      data = {'token': token2, 'user': user};
    } else if (path == '/auth/logout' && method == 'POST') {
      _userIdForToken(token);
      _tokens.remove(token);
      data = null;
      status = 204;
    } else if (path == '/me' && method == 'GET') {
      final uid = _userIdForToken(token);
      final user = _users.values.firstWhere((u) => u['id'] == uid);
      return _json(options, {
        'data': user,
        'meta': {'has_wishes': (_wishes[uid]?.isNotEmpty ?? false)},
      });
    } else if (path == '/me' && method == 'PATCH') {
      final uid = _userIdForToken(token);
      final user = _users.values.firstWhere((u) => u['id'] == uid);
      // UpdateProfileRequest: sometimes|nullable; name max:100;
      // username lowercased + regex + unique; avatar_url — url
      // max:2048. null очищает nullable-поле.
      final errors = <String, List<String>>{};
      if (body!.containsKey('name')) {
        final v = body['name'];
        if (v != null && (v is! String || v.length > 100)) {
          errors['name'] = ['The name field must be a string.'];
        }
      }
      if (body.containsKey('username')) {
        var v = body['username'];
        if (v is String) v = v.trim().toLowerCase();
        body['username'] = v;
        if (v != null &&
            (v is! String || !RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(v))) {
          errors['username'] = ['The username field format is invalid.'];
        } else if (v is String &&
            _users.values.any((u) => u['id'] != uid && u['username'] == v)) {
          errors['username'] = ['The username has already been taken.'];
        }
      }
      if (body.containsKey('avatar_url')) {
        final v = body['avatar_url'];
        if (v != null &&
            (v is! String ||
                v.length > 2048 ||
                Uri.tryParse(v)?.isAbsolute != true)) {
          errors['avatar_url'] = ['The avatar url field must be a valid URL.'];
        }
      }
      if (errors.isNotEmpty) {
        throw _error(422, 'The given data was invalid.', errors: errors);
      }
      for (final k in ['name', 'username', 'avatar_url']) {
        if (body.containsKey(k)) user[k] = body[k];
      }
      user['updated_at'] = DateTime.now().toIso8601String();
      data = user;
    } else if (path == '/users/search' && method == 'GET') {
      final uid = _userIdForToken(token);
      var q = (options.queryParameters['q'] as String? ?? '').trim();
      if (q.startsWith('@')) q = q.substring(1);
      final ql = q.toLowerCase();
      final results = <Map<String, dynamic>>[];
      if (ql.isNotEmpty) {
        for (final u in _users.values) {
          if (u['id'] == uid) continue; // себя не ищем
          final name = (u['name'] as String? ?? '').toLowerCase();
          final username = (u['username'] as String? ?? '').toLowerCase();
          if (username.startsWith(ql) || name.contains(ql)) {
            results.add(_publicUser(u, uid));
          }
        }
        results.sort(
          (a, b) => (a['name'] as String? ?? '').compareTo(
            b['name'] as String? ?? '',
          ),
        );
      }
      return _json(options, {'data': results.take(20).toList()});
    } else if (path == '/friends' && method == 'GET') {
      final uid = _userIdForToken(token);
      final friends =
          [
            for (final fid in (_friendships[uid] ?? const <String>{}))
              _publicUser(_userById(fid)!, uid),
          ]..sort((a, b) {
            final byName = (a['name'] as String? ?? '').compareTo(
              b['name'] as String? ?? '',
            );
            if (byName != 0) return byName;
            final byUsername = (a['username'] as String? ?? '').compareTo(
              b['username'] as String? ?? '',
            );
            if (byUsername != 0) return byUsername;
            return (a['id'] as String).compareTo(b['id'] as String);
          });
      return _json(options, {'data': friends});
    } else if (path == '/friends' && method == 'POST') {
      final uid = _userIdForToken(token);
      final friendId = body!['user_id'] as String?;
      if (friendId == null || friendId == uid) {
        throw _error(422, 'The given data was invalid.');
      }
      final target = _userById(friendId);
      if (target == null) {
        throw _error(422, 'The given data was invalid.');
      }
      if ((_friendships[uid] ?? const {}).contains(friendId)) {
        throw _error(409, 'Friendship already exists.');
      }
      _friendships.putIfAbsent(uid, () => {}).add(friendId);
      _friendships.putIfAbsent(friendId, () => {}).add(uid);
      status = 201;
      data = _publicUser(target, uid);
    } else if (path.startsWith('/friends/')) {
      final uid = _userIdForToken(token);
      final rest = path.substring(9);
      final friendId = rest.endsWith('/wishes')
          ? rest.substring(0, rest.length - 7)
          : rest;
      if (!(_friendships[uid] ?? const {}).contains(friendId)) {
        throw _error(404, 'Not found.');
      }
      final target = _userById(friendId);
      if (target == null) throw _error(404, 'Not found.');
      if (rest.endsWith('/wishes') && method == 'GET') {
        final list = (_wishes[friendId] ?? {}).values.toList()
          ..sort(
            (a, b) => (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            ),
          );
        return _json(options, {'data': list});
      }
      if (method == 'GET') {
        data = _publicUser(target, uid);
      } else if (method == 'DELETE') {
        _friendships[uid]?.remove(friendId);
        _friendships[friendId]?.remove(uid);
        status = 204;
        data = null;
      }
    } else if (path == '/media/uploads' && method == 'POST') {
      final uid = _userIdForToken(token);
      final purpose = body!['purpose'] as String?;
      final entityId = body['entity_id'] as String?;
      final contentType = body['content_type'] as String?;
      final size = body['size'];
      final clientId = body['client_id'] as String?;

      if (!{'avatar', 'wish', 'shopping'}.contains(purpose)) {
        throw _error(422, 'The given data was invalid.');
      }
      if (!{'image/jpeg', 'image/png', 'image/webp'}.contains(contentType)) {
        throw _error(422, 'The given data was invalid.');
      }
      if (size is! int || size < 1 || size > 5 * 1024 * 1024) {
        throw _error(422, 'The given data was invalid.');
      }
      if (purpose == 'wish' || purpose == 'shopping') {
        final owned = purpose == 'wish'
            ? (_wishes[uid] ?? {}).containsKey(entityId)
            : (_shoppingLists[uid] ?? {}).containsKey(entityId);
        if (!owned) throw _error(404, 'Not found.');
      }

      // Idempotency: тот же client_id → тот же upload и object key.
      final indexKey = '$uid|$clientId';
      var upload = clientId != null
          ? _mediaUploads[_mediaClientIndex[indexKey]]
          : null;
      if (upload == null) {
        final uploadId = _uuid.v4();
        final imageId = _uuid.v4();
        final ext = contentType == 'image/jpeg'
            ? 'jpg'
            : contentType == 'image/png'
            ? 'png'
            : 'webp';
        final objectKey = purpose == 'avatar'
            ? 'chtohochu-avatars/users/$uid/avatar/$imageId.$ext'
            : purpose == 'wish'
            ? 'chtohochu-wish-images/users/$uid/wishes/$entityId/$imageId.$ext'
            : 'chtohochu-shopping-images/users/$uid/shopping-lists/$entityId/$imageId.$ext';
        upload = {
          'upload_id': uploadId,
          'user_id': uid,
          'object_key': objectKey,
          'status': 'pending',
          'remote_url': 'https://cdn.test/$objectKey',
        };
        _mediaUploads[uploadId] = upload;
        if (clientId != null) _mediaClientIndex[indexKey] = uploadId;
      }
      status = 201;
      data = {
        'upload_id': upload['upload_id'],
        'upload_url': 'fake-put://${upload['upload_id']}',
        'upload_headers': {'Content-Type': contentType},
        'method': 'PUT',
        'object_key': upload['object_key'],
        'remote_url': upload['remote_url'],
        'status': upload['status'],
        'expires_at': DateTime.now()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
        'purpose': purpose,
        'entity_id': entityId,
        'client_id': clientId,
      };
    } else if (path.startsWith('/media/uploads/') &&
        path.endsWith('/complete') &&
        method == 'POST') {
      final uid = _userIdForToken(token);
      final uploadId = path.substring(
        '/media/uploads/'.length,
        path.length - '/complete'.length,
      );
      final upload = _mediaUploads[uploadId];
      if (upload == null || upload['user_id'] != uid) {
        throw _error(404, 'Not found.');
      }
      // Backend требует существования объекта: фиктивный PUT
      // регистрируется через markMediaObjectPut в тесте.
      if (upload['status'] != 'put' && upload['status'] != 'uploaded') {
        throw _error(422, 'Object not found.');
      }
      upload['status'] = 'uploaded';
      data = {
        'upload_id': uploadId,
        'status': 'uploaded',
        'remote_url': upload['remote_url'],
      };
    } else if (path == '/wishes' && method == 'GET') {
      final uid = _userIdForToken(token);
      final list = (_wishes[uid] ?? {}).values.toList()
        ..sort(
          (a, b) =>
              (b['created_at'] as String).compareTo(a['created_at'] as String),
        );
      data = null;
      return _json(options, {'data': list});
    } else if (path == '/wishes' && method == 'POST') {
      final uid = _userIdForToken(token);
      final wishes = _wishes.putIfAbsent(uid, () => {});
      final id = body!['id'] as String? ?? _uuid.v4();
      if (wishes.containsKey(id)) {
        throw _error(409, 'Resource already exists.');
      }
      final now = DateTime.now().toIso8601String();
      final wish = {
        'id': id,
        'title': body['title'],
        'description': body['description'],
        'price': body['price'],
        'link': body['link'],
        'image_url': body['image_url'],
        'created_at': now,
        'updated_at': now,
      };
      wishes[id] = wish;
      status = 201;
      data = wish;
    } else if (path == '/shopping-lists' && method == 'GET') {
      final uid = _userIdForToken(token);
      final lists =
          (_shoppingLists[uid] ?? {}).values.map(_serializeList).toList()..sort(
            (a, b) => (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            ),
          );
      return _json(options, {'data': lists});
    } else if (path == '/shopping-lists' && method == 'POST') {
      final uid = _userIdForToken(token);
      final lists = _shoppingLists.putIfAbsent(uid, () => {});
      final id = body!['id'] as String? ?? _uuid.v4();
      if (lists.containsKey(id)) {
        throw _error(409, 'Resource already exists.');
      }
      final now = DateTime.now().toIso8601String();
      final list = <String, dynamic>{
        'id': id,
        'title': body['title'],
        'created_at': now,
        'updated_at': now,
        'items': <String, Map<String, dynamic>>{},
      };
      lists[id] = list;
      status = 201;
      data = _serializeList(list);
    } else if (path.startsWith('/shopping-items/')) {
      final uid = _userIdForToken(token);
      final id = path.substring(16);
      final ref = _findItem(uid, id);
      if (ref == null) throw _error(404, 'Not found.');
      final (list, item) = ref;
      if (method == 'PATCH') {
        for (final k in ['title', 'quantity', 'is_checked']) {
          if (body!.containsKey(k)) item[k] = body[k];
        }
        item['updated_at'] = DateTime.now().toIso8601String();
        list['updated_at'] = DateTime.now().toIso8601String();
        data = item;
      } else if (method == 'DELETE') {
        (list['items'] as Map<String, Map<String, dynamic>>).remove(id);
        status = 204;
        data = null;
      }
    } else if (path.startsWith('/shopping-lists/')) {
      final uid = _userIdForToken(token);
      final rest = path.substring(16);
      if (rest.endsWith('/items') && method == 'POST') {
        final list =
            (_shoppingLists[uid] ?? {})[rest.substring(0, rest.length - 6)];
        if (list == null) throw _error(404, 'Not found.');
        final items = list['items'] as Map<String, Map<String, dynamic>>;
        final id = body!['id'] as String? ?? _uuid.v4();
        if (items.containsKey(id)) {
          throw _error(409, 'Resource already exists.');
        }
        final now = DateTime.now().toIso8601String();
        final item = <String, dynamic>{
          'id': id,
          'title': body['title'],
          // is_checked намеренно не принимается при create —
          // как в backend (server default false).
          'quantity': body['quantity'] as int? ?? 1,
          'is_checked': false,
          'created_at': now,
          'updated_at': now,
        };
        items[id] = item;
        status = 201;
        data = item;
      } else {
        final list = (_shoppingLists[uid] ?? {})[rest];
        if (list == null) throw _error(404, 'Not found.');
        if (method == 'GET') {
          data = _serializeList(list);
        } else if (method == 'PATCH') {
          if (body!.containsKey('title')) list['title'] = body['title'];
          list['updated_at'] = DateTime.now().toIso8601String();
          data = _serializeList(list);
        } else if (method == 'DELETE') {
          _shoppingLists[uid]!.remove(rest);
          status = 204;
          data = null;
        }
      }
    } else {
      final m = RegExp(r'^/wishes/(' + _uuidRe + r'|[^/]+)$').firstMatch(path);
      if (m != null) {
        final uid = _userIdForToken(token);
        final wishes = _wishes[uid] ?? {};
        final wish = wishes[path.substring(8)];
        if (wish == null) throw _error(404, 'Not found.');
        if (method == 'GET') {
          data = wish;
        } else if (method == 'PATCH') {
          for (final k in [
            'title',
            'description',
            'price',
            'link',
            'image_url',
          ]) {
            if (body!.containsKey(k)) wish[k] = body[k];
          }
          wish['updated_at'] = DateTime.now().toIso8601String();
          data = wish;
        } else if (method == 'DELETE') {
          wishes.remove(path.substring(8));
          status = 204;
          data = null;
        }
      }
    }

    if (data == null && status == 200) {
      throw _error(404, 'Not found.');
    }
    return _json(options, data == null ? null : {'data': data}, status: status);
  }

  /// Пользователь по id (auto-vivified и seed'нутые вместе).
  Map<String, dynamic>? _userById(String id) {
    for (final u in _users.values) {
      if (u['id'] == id) return u;
    }
    return null;
  }

  /// PublicUserResource: только публичные поля (без email).
  Map<String, dynamic> _publicUser(Map<String, dynamic> u, String viewerId) => {
    'id': u['id'],
    'name': u['name'],
    'username': u['username'],
    'avatar_url': u['avatar_url'],
    'is_friend': (_friendships[viewerId] ?? const {}).contains(u['id']),
  };

  /// Сериализация списка с позициями (как ShoppingListResource).
  Map<String, dynamic> _serializeList(Map<String, dynamic> list) => {
    'id': list['id'],
    'title': list['title'],
    'created_at': list['created_at'],
    'updated_at': list['updated_at'],
    'items': (list['items'] as Map<String, Map<String, dynamic>>).values
        .toList(),
  };

  /// Найти позицию по id среди списков пользователя.
  (Map<String, dynamic>, Map<String, dynamic>)? _findItem(
    String uid,
    String itemId,
  ) {
    for (final list in (_shoppingLists[uid] ?? {}).values) {
      final items = list['items'] as Map<String, Map<String, dynamic>>;
      final item = items[itemId];
      if (item != null) return (list, item);
    }
    return null;
  }

  ResponseBody _json(
    RequestOptions options,
    Map<String, dynamic>? json, {
    int status = 200,
  }) {
    return ResponseBody.fromString(
      json == null ? '' : jsonEncode(json),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  // ── Тестовые хелперы ───────────────────────────────────────

  /// «Серверные» желания пользователя (для assert'ов после sync).
  List<Map<String, dynamic>> wishesOf(String uid) =>
      (_wishes[uid] ?? {}).values.toList();

  /// Посеять желание на «сервере» (remote-изменение с другого
  /// устройства / потерянный ответ на create).
  void seedWish(String uid, Map<String, dynamic> wish) {
    _wishes.putIfAbsent(uid, () => {})[wish['id'] as String] = wish;
  }

  /// Удалить желание на «сервере» (remote delete с другого устройства).
  void deleteServerWish(String uid, String id) {
    _wishes[uid]?.remove(id);
  }

  /// Зафиксировать, что объект попал в «object storage» — эмуляция
  /// успешного presigned PUT перед `complete` (backend требует
  /// существования объекта).
  void markMediaObjectPut(String uploadUrl) {
    final upload = _mediaUploads[uploadUrl.replaceFirst('fake-put://', '')];
    if (upload != null) upload['status'] = 'put';
  }

  /// Media upload по id (для assert'ов статуса/object key).
  Map<String, dynamic>? mediaUploadOf(String uploadId) =>
      _mediaUploads[uploadId];

  /// «Серверные» списки покупок пользователя (для assert'ов).
  List<Map<String, dynamic>> shoppingListsOf(String uid) =>
      (_shoppingLists[uid] ?? {}).values.map(_serializeList).toList();

  /// «Серверная» позиция по id (для assert'ов).
  Map<String, dynamic>? shoppingItemOf(String uid, String itemId) =>
      _findItem(uid, itemId)?.$2;

  /// Посеять список покупок на «сервере» (remote-изменение).
  /// [items] — список map'ов позиций (id/title/quantity/is_checked).
  void seedShoppingList(
    String uid,
    String id,
    String title, {
    List<Map<String, dynamic>> items = const [],
  }) {
    final now = DateTime.now().toIso8601String();
    _shoppingLists.putIfAbsent(uid, () => {})[id] = {
      'id': id,
      'title': title,
      'created_at': now,
      'updated_at': now,
      'items': {
        for (final i in items)
          i['id'] as String: {
            'id': i['id'],
            'title': i['title'],
            'quantity': i['quantity'] ?? 1,
            'is_checked': i['is_checked'] ?? false,
            'created_at': now,
            'updated_at': now,
          },
      },
    };
  }

  /// Удалить список на «сервере» (remote delete, каскад позиций).
  void deleteServerShoppingList(String uid, String id) {
    _shoppingLists[uid]?.remove(id);
  }

  /// Удалить позицию на «сервере» (remote delete с другого устройства).
  void deleteServerShoppingItem(String uid, String id) {
    _findItem(uid, id)?.$1['items']?.remove(id);
  }

  // ── Friends ──────────────────────────────────────────────

  /// Посеять пользователя на «сервере» (для поиска/дружбы).
  /// Возвращает его id (как у [_newUser], с заданным id).
  Map<String, dynamic> seedUser(
    String id, {
    String? name,
    String? username,
    String? avatarUrl,
  }) {
    final user = _newUser(
      'seed-$id@chtohochu.ru',
      name: name,
      username: username,
    );
    user['id'] = id;
    user['avatar_url'] = avatarUrl;
    _users[user['email'] as String] = user;
    _wishes.putIfAbsent(id, () => {});
    _shoppingLists.putIfAbsent(id, () => {});
    return user;
  }

  /// Remote-изменение пользователя (другое устройство поменяло
  /// профиль): `fields` — server-поля в snake_case.
  void updateServerUser(String id, Map<String, dynamic> fields) {
    _userById(id)?.addAll(fields);
  }

  /// «Серверный» пользователь по id (для assert'ов).
  Map<String, dynamic>? serverUser(String id) => _userById(id);

  /// Симметричная дружба на «сервере» (remote-изменение).
  void seedFriendship(String uid, String friendId) {
    _friendships.putIfAbsent(uid, () => {}).add(friendId);
    _friendships.putIfAbsent(friendId, () => {}).add(uid);
  }

  /// Remote-удаление дружбы (симметрично).
  void deleteServerFriendship(String uid, String friendId) {
    _friendships[uid]?.remove(friendId);
    _friendships[friendId]?.remove(uid);
  }

  /// «Серверные» друзья пользователя (id'ы — для assert'ов).
  Set<String> friendsOf(String uid) =>
      Set.unmodifiable(_friendships[uid] ?? const <String>{});

  @override
  void close({bool force = false}) {}
}
