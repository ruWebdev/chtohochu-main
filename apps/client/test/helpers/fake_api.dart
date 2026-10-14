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

  /// uid → listId → wish list {'id','title','created_at','updated_at'}.
  final _wishLists = <String, Map<String, Map<String, dynamic>>>{};

  /// `'$uid|wish:$id'` / `'$uid|list:$id'` → share
  /// {'id','token','url','revoked_at','entity','uid'}.
  final _shares = <String, Map<String, dynamic>>{};

  /// Искусственная задержка ответа — для тестов «запрос ещё
  /// выполняется» (in-flight guards).
  Duration latency = Duration.zero;

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
      'vk_id': null,
      'yandex_id': null,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Пользователь по provider-колонке (`vk_id`/`yandex_id`).
  Map<String, dynamic>? _userByProvider(String column, String providerId) {
    for (final u in _users.values) {
      if (u[column] == providerId) return u;
    }
    return null;
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
      _wishLists.putIfAbsent(user['id'] as String, () => {});
      return user['id'] as String;
    });
  }

  DioException _unauthorized() => _error(401, 'Unauthenticated.');

  DioException _error(
    int code,
    String message, {
    Map<String, dynamic>? errors,
    String? errorCode,
  }) {
    return DioException(
      requestOptions: RequestOptions(),
      response: Response(
        requestOptions: RequestOptions(),
        statusCode: code,
        data: {'message': message, 'errors': ?errors, 'code': ?errorCode},
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
    if (latency > Duration.zero) await Future.delayed(latency);
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
    } else if ((path == '/auth/vk/link' || path == '/auth/yandex/link') &&
        method == 'POST') {
      // Подтверждённая привязка (auth:sanctum) — контракт
      // SocialAuthController::link.
      final provider = path.split('/')[2];
      final uid = _userIdForToken(token);
      final user = _users.values.firstWhere((u) => u['id'] == uid);
      final accessToken = body!['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        throw _error(
          422,
          'The given data was invalid.',
          errors: {
            'access_token': ['The access token field is required.'],
          },
        );
      }
      final pidCol = '${provider}_id';
      final pid = 'pid_$accessToken';
      if (_users.values.any((u) => u['id'] != uid && u[pidCol] == pid)) {
        throw _error(
          409,
          'Provider account is taken.',
          errorCode: 'oauth_provider_taken',
        );
      }
      if (user[pidCol] != null && user[pidCol] != pid) {
        throw _error(
          409,
          'Another account is already linked.',
          errorCode: 'oauth_already_linked',
        );
      }
      user[pidCol] = pid;
      user['updated_at'] = DateTime.now().toIso8601String();
      data = {'user': user};
    } else if ((path == '/auth/vk' || path == '/auth/yandex') &&
        method == 'POST') {
      // Обмен provider-токена на сессию — контракт
      // SocialAuthController::{vk,yandex}. 'bad-token' имитирует
      // отказ провайдера.
      final provider = path.split('/').last;
      final accessToken = body!['access_token'] as String?;
      if (accessToken == null ||
          accessToken.isEmpty ||
          accessToken == 'bad-token') {
        throw _error(
          422,
          'The given data was invalid.',
          errors: {
            'access_token': ['Failed to verify the provider token.'],
          },
        );
      }
      final pidCol = '${provider}_id';
      final pid = 'pid_$accessToken';
      var user = _userByProvider(pidCol, pid);
      if (user == null) {
        var email = body['email'] as String?;
        // У Яндекса email приходит «от провайдера» — в фейке
        // детерминированно выводим из токена.
        email ??= provider == 'yandex' ? 'ya_$accessToken@yandex.ru' : null;
        if (email != null && _users.containsKey(email)) {
          throw _error(
            409,
            'Account link required.',
            errorCode: 'oauth_link_required',
          );
        }
        final emailForCreate =
            email ?? '${provider}_${pid.substring(4)}@$provider.local';
        user = _newUser(emailForCreate);
        user[pidCol] = pid;
        _users[emailForCreate] = user;
        _wishes.putIfAbsent(user['id'] as String, () => {});
        _shoppingLists.putIfAbsent(user['id'] as String, () => {});
        _wishLists.putIfAbsent(user['id'] as String, () => {});
      }
      final token2 = _uuid.v4();
      _tokens[token2] = user['id'] as String;
      data = {'token': token2, 'user': user};
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
        final list = (_wishes[friendId] ?? {}).values.map(_wishJson).toList()
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
      final list = (_wishes[uid] ?? {}).values.map(_wishJson).toList()
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
      // Backend-валидация membership: только свой живой список.
      final lid = body['list_id'];
      if (lid != null && !(_wishLists[uid] ?? {}).containsKey(lid)) {
        throw _error(422, 'The given data was invalid.');
      }
      _validatePriority(body);
      final now = DateTime.now().toIso8601String();
      final wish = {
        'id': id,
        'title': body['title'],
        'description': body['description'],
        'price': body['price'],
        'link': body['link'],
        'image_url': body['image_url'],
        'list_id': body['list_id'],
        // Backend-дефолт: поле необязательно в create.
        'priority': body['priority'] ?? 'normal',
        'images': _parseImagesField(body['images']),
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
        'owner_id': uid,
        'members': <Map<String, dynamic>>[],
        'revision': 0,
        'created_at': now,
        'updated_at': now,
        'items': <String, Map<String, dynamic>>{},
      };
      lists[id] = list;
      status = 201;
      data = _serializeList(list);
    } else if (path == '/wish-lists' && method == 'GET') {
      final uid = _userIdForToken(token);
      final lists = (_wishLists[uid] ?? {}).values.toList()
        ..sort(
          (a, b) =>
              (b['created_at'] as String).compareTo(a['created_at'] as String),
        );
      return _json(options, {'data': lists});
    } else if (path == '/wish-lists' && method == 'POST') {
      final uid = _userIdForToken(token);
      final lists = _wishLists.putIfAbsent(uid, () => {});
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
      };
      lists[id] = list;
      status = 201;
      data = list;
    } else if (path.startsWith('/wish-lists/')) {
      final uid = _userIdForToken(token);
      final rest = path.substring(12);
      if (rest.endsWith('/share') && method == 'POST') {
        // POST /wish-lists/{id}/share — идемпотентно, как backend.
        final id = rest.substring(0, rest.length - 6);
        if (!(_wishLists[uid] ?? {}).containsKey(id)) {
          throw _error(404, 'Not found.');
        }
        status = 201;
        data = _shareFor(uid, 'list:$id');
      } else {
        final list = (_wishLists[uid] ?? {})[rest];
        if (list == null) throw _error(404, 'Not found.');
        if (method == 'GET') {
          data = list;
        } else if (method == 'PATCH') {
          if (body!.containsKey('title')) list['title'] = body['title'];
          list['updated_at'] = DateTime.now().toIso8601String();
          data = list;
        } else if (method == 'DELETE') {
          _wishLists[uid]!.remove(rest);
          // Как backend: soft-delete списка разгруппировывает wishes.
          for (final w in (_wishes[uid] ?? {}).values) {
            if (w['list_id'] == rest) w['list_id'] = null;
          }
          status = 204;
          data = null;
        }
      }
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
      // Участники: GET/POST /{id}/members, DELETE /{id}/members/{userId}.
      if (rest.endsWith('/members') && method == 'POST') {
        final listId = rest.substring(0, rest.length - 8);
        final list = (_shoppingLists[uid] ?? {})[listId];
        if (list == null) throw _error(404, 'Not found.');
        final memberId = body!['user_id'] as String;
        final members = (list['members'] as List).cast<Map<String, dynamic>>();
        if (!members.any((m) => m['id'] == memberId)) {
          // Seed'ы могут отдать const/unmodifiable — переприсваиваем.
          list['members'] = [...members, _serializeUser(memberId)];
          list['revision'] = (list['revision'] as int? ?? 0) + 1;
          status = 201;
        } else {
          status = 200; // идемпотентно, как backend
        }
        data = _serializeUser(memberId);
      } else if (rest.endsWith('/members') && method == 'GET') {
        final listId = rest.substring(0, rest.length - 8);
        final list = (_shoppingLists[uid] ?? {})[listId];
        if (list == null) throw _error(404, 'Not found.');
        return _json(options, {
          'data': [
            _serializeUser(list['owner_id'] as String),
            ...(list['members'] as List).cast<Map<String, dynamic>>(),
          ],
        });
      } else if (rest.contains('/members/') && method == 'DELETE') {
        final i = rest.indexOf('/members/');
        final listId = rest.substring(0, i);
        final memberId = rest.substring(i + 9);
        final list = (_shoppingLists[uid] ?? {})[listId];
        if (list == null) throw _error(404, 'Not found.');
        // Владельца удалить нельзя.
        if (memberId == list['owner_id']) throw _error(404, 'Not found.');
        final members = (list['members'] as List).cast<Map<String, dynamic>>();
        // Seed'ы могут отдать const/unmodifiable — переприсваиваем.
        list['members'] = [
          for (final m in members)
            if (m['id'] != memberId) m,
        ];
        list['revision'] = (list['revision'] as int? ?? 0) + 1;
        status = 204;
        data = null;
      } else if (rest.endsWith('/items') && method == 'POST') {
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
          data = _wishJson(wish);
        } else if (method == 'PATCH') {
          final lid = body?['list_id'];
          if (lid != null && !(_wishLists[uid] ?? {}).containsKey(lid)) {
            throw _error(422, 'The given data was invalid.');
          }
          _validatePriority(body);
          for (final k in [
            'title',
            'description',
            'price',
            'link',
            'image_url',
            'list_id',
            'priority',
          ]) {
            if (body!.containsKey(k)) wish[k] = body[k];
          }
          // `images`: отсутствует = не трогать, [] = очистить,
          // […] = полная замена (порядок массива → sort_order).
          if (body!.containsKey('images')) {
            wish['images'] = _parseImagesField(body['images']);
          }
          wish['updated_at'] = DateTime.now().toIso8601String();
          data = _wishJson(wish);
        } else if (method == 'DELETE') {
          wishes.remove(path.substring(8));
          status = 204;
          data = null;
        }
      }
    }

    // --- Sharing ---
    if (data == null && status == 200) {
      final shareCreate = RegExp(r'^/wishes/[^/]+/share$').firstMatch(path);
      if (shareCreate != null && method == 'POST') {
        final uid = _userIdForToken(token);
        final id = path.substring(8, path.length - 6);
        if (!(_wishes[uid] ?? {}).containsKey(id)) {
          throw _error(404, 'Not found.');
        }
        return _json(options, {
          'data': _shareFor(uid, 'wish:$id'),
        }, status: 201);
      }
      final shareDelete = RegExp(r'^/shares/[^/]+$').firstMatch(path);
      if (shareDelete != null && method == 'DELETE') {
        final uid = _userIdForToken(token);
        final share = _shares.values.where(
          (s) => s['uid'] == uid && s['id'] == path.substring(8),
        );
        if (share.isEmpty) throw _error(404, 'Not found.');
        share.first['revoked_at'] = DateTime.now().toIso8601String();
        return _json(options, null, status: 204);
      }
      final sharePublic = RegExp(r'^/share/[^/]+$').firstMatch(path);
      if (sharePublic != null && method == 'GET') {
        // Публичный resolver — без auth-токена.
        final tokenStr = path.substring(7);
        final share = _shares.values.where(
          (s) => s['token'] == tokenStr && s['revoked_at'] == null,
        );
        if (share.isEmpty) throw _error(404, 'Not found.');
        final s = share.first;
        final uid = s['uid'] as String;
        final entity = s['entity'] as String;
        if (entity.startsWith('wish:')) {
          final w = (_wishes[uid] ?? {})[entity.substring(5)];
          if (w == null) throw _error(404, 'Not found.');
          return _json(options, {'type': 'wish', 'data': _publicWish(uid, w)});
        }
        final l = (_wishLists[uid] ?? {})[entity.substring(5)];
        if (l == null) throw _error(404, 'Not found.');
        final wishes = (_wishes[uid] ?? {}).values
            .where((w) => w['list_id'] == l['id'])
            .map((w) => _publicWish(uid, w)..remove('owner'))
            .toList();
        return _json(options, {
          'type': 'wish_list',
          'data': {
            'title': l['title'],
            'owner': {
              'name': _users.values.firstWhere((u) => u['id'] == uid)['name'],
            },
            'wishes': wishes,
          },
        });
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
    'owner_id': list['owner_id'],
    'owner': _serializeUser(list['owner_id'] as String),
    'members': list['members'] ?? const [],
    'revision': list['revision'] ?? 0,
    'created_at': list['created_at'],
    'updated_at': list['updated_at'],
    'items': (list['items'] as Map<String, Map<String, dynamic>>).values
        .toList(),
  };

  /// PublicUserResource-проекция пользователя.
  Map<String, dynamic> _serializeUser(String id) {
    Map<String, dynamic>? u;
    for (final candidate in _users.values) {
      if (candidate['id'] == id) {
        u = candidate;
        break;
      }
    }
    return {
      'id': id,
      'name': u?['name'] as String? ?? id,
      'username': u?['username'] as String? ?? id,
      'avatar_url': u?['avatar_url'],
      'is_friend': true,
    };
  }

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
  /// [ownerId] — серверный владелец (для shared-списка чужой id);
  /// [members] — участники (PublicUserResource-формы {id,name,...}).
  void seedShoppingList(
    String uid,
    String id,
    String title, {
    List<Map<String, dynamic>> items = const [],
    String? ownerId,
    List<Map<String, dynamic>> members = const [],
  }) {
    final now = DateTime.now().toIso8601String();
    _shoppingLists.putIfAbsent(uid, () => {})[id] = {
      'id': id,
      'title': title,
      'owner_id': ownerId ?? uid,
      'members': members,
      'revision': 0,
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

  // ── Wish lists ───────────────────────────────────────────

  /// «Серверные» списки желаний пользователя (для assert'ов).
  List<Map<String, dynamic>> wishListsOf(String uid) =>
      (_wishLists[uid] ?? {}).values.toList();

  /// Посеять список желаний на «сервере» (remote-изменение).
  /// Идемпотентный share: активный уже есть — возвращаем его,
  /// как backend (`owner + entity → один active share`).
  Map<String, dynamic> _shareFor(String uid, String entity) {
    final key = '$uid|$entity';
    final existing = _shares[key];
    if (existing != null && existing['revoked_at'] == null) {
      return {'token': existing['token'], 'url': existing['url']};
    }
    final token = 'tok-${_uuid.v4()}';
    final share = <String, dynamic>{
      'id': _uuid.v4(),
      'token': token,
      'url': 'https://app.chtohochu.ru/s/$token',
      'revoked_at': null,
      'entity': entity,
      'uid': uid,
    };
    _shares[key] = share;
    return {'token': token, 'url': share['url']};
  }

  /// Создаёт активный share напрямую (как после `POST .../share`)
  /// и возвращает его capability-токен для `GET /share/{token}`.
  String seedShare(String uid, String entity) =>
      _shareFor(uid, entity)['token'] as String;

  /// Нормализация wish-записи: `images` присутствует всегда
  /// (старые seed'ы без поля → `[]`) — как WishResource.
  Map<String, dynamic> _wishJson(Map<String, dynamic> w) => {
    ...w,
    'images': w['images'] ?? const [],
  };

  /// Backend-валидация `priority` (`Rule::in`): только при
  /// наличии поля — отсутствующее не сбрасывает старое значение.
  void _validatePriority(Map<String, dynamic>? body) {
    final p = body?['priority'];
    if (p != null && p is! String ||
        p is String && !{'later', 'normal', 'high'}.contains(p)) {
      throw _error(422, 'The given data was invalid.');
    }
  }

  /// Валидация+нормализация поля `images` (POST/PATCH): каждый
  /// элемент — `{id?: uuid, url: string}`; индекс → sort_order.
  List<Map<String, dynamic>> _parseImagesField(Object? field) {
    if (field == null) return [];
    if (field is! List) throw _error(422, 'The given data was invalid.');
    return [
      for (var i = 0; i < field.length; i++)
        () {
          final img = field[i];
          if (img is! Map || img['url'] is! String) {
            throw _error(422, 'The given data was invalid.');
          }
          return {
            'id': (img['id'] as String?) ?? _uuid.v4(),
            'url': img['url'],
            'sort_order': i + 1,
          };
        }(),
    ];
  }

  /// Публичная проекция желания — как SharedWishResource.
  Map<String, dynamic> _publicWish(String uid, Map<String, dynamic> w) => {
    'title': w['title'],
    'price': w['price'],
    'link': w['link'],
    'image_url': w['image_url'],
    'images': _wishJson(w)['images'],
    'owner': {
      'name': _users.values.firstWhere(
        (u) => u['id'] == uid,
        orElse: () => {'name': null},
      )['name'],
    },
  };

  void seedWishList(String uid, String id, String title) {
    final now = DateTime.now().toIso8601String();
    _wishLists.putIfAbsent(uid, () => {})[id] = {
      'id': id,
      'title': title,
      'created_at': now,
      'updated_at': now,
    };
  }

  /// Удалить список желаний на «сервере» (remote delete).
  void deleteServerWishList(String uid, String id) {
    _wishLists[uid]?.remove(id);
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
