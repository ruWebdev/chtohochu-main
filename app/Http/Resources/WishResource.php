<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WishResource extends JsonResource
{
    /**
     * Преобразование ресурса в массив для API.
     */
    public function toArray(Request $request): array
    {
        $claimers = $this->whenLoaded('claimers');
        $comments = $this->whenLoaded('comments');
        $likes = $this->whenLoaded('likes');
        $history = $this->whenLoaded('history');
        $attachments = $this->whenLoaded('attachments');
        $owner = $this->whenLoaded('owner');

        $user = $request->user();
        $isOwner = $user && $this->owner_id === $user->id;

        $data = [
            'id' => $this->id,
            'wishlist_id' => $this->wishlist_id,
            'owner_id' => $this->owner_id,
            'owner_name' => $owner?->name ?? $this->owner?->name,
            'owner_avatar' => $owner?->avatar ?? $this->owner?->avatar,
            'name' => $this->name,
            'description' => $this->description,
            'visibility' => $this->visibility,
            'images' => $this->images ?? [],
            'link' => $this->url,
            'necessity' => $this->necessity,
            'priority' => $this->priority,
            'desired_price' => $this->desired_price,
            'price_min' => $this->price_min,
            'price_max' => $this->price_max,
            'hide_price' => (bool) $this->hide_price,
            'categories' => $this->tags ?? [],
            'status' => $this->status,
            'in_progress' => (bool) $this->in_progress,
            'claimers' => WishClaimerResource::collection($claimers ?? []),
            'allow_claiming' => (bool) ($this->allow_claiming ?? true),
            'allow_comments' => (bool) ($this->allow_comments ?? true),
            'allow_sharing' => (bool) ($this->allow_sharing ?? true),
            'deadline_date' => optional($this->deadline_at)?->toISOString(),
            'sort_index' => $this->sort_index,
            'created_at' => optional($this->created_at)?->toISOString(),
            'updated_at' => optional($this->updated_at)?->toISOString(),

            // Расширенные поля
            'checklist' => $this->checklist ?? [],
            'comments_count' => $this->comments_count ?? $this->comments()->count(),
            'likes_count' => $this->likes_count ?? $this->likes()->count(),
            'is_liked_by_me' => $user ? $this->isLikedByUser($user) : false,
            'purchase_receipt' => $this->purchase_receipt,
            'purchase_date' => optional($this->purchase_date)?->toISOString(),

            // Права доступа
            'permissions' => $this->getPermissionsForUser($user),
        ];

        // Приватные заметки только для владельца
        if ($isOwner) {
            $data['private_notes'] = $this->private_notes;
        }

        // Комментарии (если загружены)
        if ($comments !== null) {
            $data['comments'] = WishCommentResource::collection($comments);
        }

        // Лайки (если загружены)
        if ($likes !== null) {
            $data['likes'] = WishLikeResource::collection($likes);
        }

        // История изменений (только для владельца, если загружена)
        if ($isOwner && $history !== null) {
            $data['history'] = WishHistoryResource::collection($history);
        }

        // Прикреплённые файлы (если загружены)
        if ($attachments !== null) {
            $data['attachments'] = WishAttachmentResource::collection($attachments);
        }

        return $data;
    }
}
