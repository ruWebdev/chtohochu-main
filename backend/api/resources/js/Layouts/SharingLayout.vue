<template>
    <div class="sharing-layout min-h-screen bg-[#F9FAFB] flex justify-center">
        <div class="w-full max-w-md flex flex-col">
            <header class="sharing-header flex items-center justify-center h-14 px-4 border-b border-gray-200 bg-white">
                <span class="text-base font-semibold tracking-wide text-gray-900">
                    ЧтоХочу
                </span>
            </header>
            <main class="flex-1 px-4 py-4">
                <slot />
            </main>
        </div>
    </div>
</template>

<script setup>
</script>
