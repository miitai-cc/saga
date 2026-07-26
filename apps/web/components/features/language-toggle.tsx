"use client";

import * as React from "react";
import { Languages } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { persistLocale } from "@/i18n/client";
import type { AppLocale } from "@/i18n/config";

const LANGUAGES = [
  { value: "zh-TW", label: "繁體中文" },
  { value: "en-US", label: "English" },
  { value: "ja-JP", label: "日本語" },
  { value: "nl-NL", label: "Nederlands" },
  { value: "zh-CN", label: "简体中文" },
] as const;

export function LanguageToggle({ className }: { className?: string }) {
  const locale = useLocale();
  const t = useTranslations("Language");
  const router = useRouter();
  const [pending, startTransition] = React.useTransition();

  const switchLocale = (newLocale: AppLocale) => {
    if (pending || newLocale === locale) return;
    persistLocale(newLocale);
    startTransition(() => router.refresh());
  };

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          type="button"
          variant="ghost"
          size="icon"
          className={className}
          aria-label={t("label")}
          aria-busy={pending}
          disabled={pending}
        >
          <Languages className="size-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {LANGUAGES.map((lang) => (
          <DropdownMenuItem
            key={lang.value}
            onClick={() => switchLocale(lang.value as AppLocale)}
            className={locale === lang.value ? "bg-accent" : ""}
          >
            {lang.label}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
