/*
 * [INPUT]: Depends on React children and link destinations supplied by callers.
 * [OUTPUT]: Provides editorial section headings and article lists shared by product and content routes.
 * [POS]: Serves as the reusable content-pattern module inside the SkillsGo design system.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import type { ReactNode } from 'react';

export type EditorialSectionHeaderProps = {
  eyebrow?: ReactNode;
  title: ReactNode;
  description?: ReactNode;
  titleHref?: string;
};

export function EditorialSectionHeader({ eyebrow, title, description, titleHref }: EditorialSectionHeaderProps) {
  return (
    <div className="section-head">
      {eyebrow ? <p className="section-num">{eyebrow}</p> : null}
      <h2 className="section-title">{titleHref ? <a href={titleHref}>{title}</a> : title}</h2>
      {description ? <p className="section-lede">{description}</p> : null}
    </div>
  );
}

export type ArticleListItem = {
  href: string;
  title: string;
  date: string;
  language?: string;
};

export function ArticleList({ items }: { items: readonly ArticleListItem[] }) {
  return (
    <ul className="blog-latest-list">
      {items.map((item) => (
        <li key={item.href}>
          <a href={item.href}>
            <span className="blog-latest-title" lang={item.language}>{item.title}</span>
            <time className="blog-latest-date" dateTime={item.date}>{item.date}</time>
          </a>
        </li>
      ))}
    </ul>
  );
}
