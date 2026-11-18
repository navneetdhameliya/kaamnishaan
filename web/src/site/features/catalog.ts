import {
  Bell,
  BookOpen,
  Briefcase,
  Camera,
  CircleCheck,
  CircleHelp,
  Clock,
  CloudOff,
  Download,
  Eye,
  FileText,
  Fingerprint,
  Globe,
  Hash,
  Home as HomeIcon,
  Image as ImageIcon,
  Languages,
  Link2,
  ListChecks,
  Lock,
  MapPin,
  MessageCircle,
  MessageSquareReply,
  Mic,
  Palette,
  Phone,
  Plus,
  RefreshCw,
  RotateCcw,
  Search,
  ShieldCheck,
  Smartphone,
  Sparkles,
  Star,
  TriangleAlert,
  Upload,
  UserCheck,
  Users,
  WifiOff,
  type LucideIcon,
} from 'lucide-react';

/**
 * The website's feature pages (W08 overview, W09–W17, W31). The words live in shared/i18n under
 * site.fp.<id>.*; this file only says which pictures and icons each page uses and how pages link.
 */
export type FeatureId = 'jobs' | 'evidence' | 'checklists' | 'voice' | 'reports' | 'assistant' | 'pdf' | 'sharing' | 'offline' | 'reviews';

export interface Feature {
  id: FeatureId;
  slug: string;
  icon: LucideIcon;
  /** Photo for the "Related features" card. */
  cover: string;
}

const P = (name: string) => `/img/photo-${name}.webp`;

export const FEATURES: Feature[] = [
  { id: 'jobs', slug: 'jobs', icon: Briefcase, cover: P('clinic') },
  { id: 'evidence', slug: 'evidence-capture', icon: Camera, cover: P('phonecam') },
  { id: 'checklists', slug: 'checklists', icon: ListChecks, cover: P('indoor') },
  { id: 'voice', slug: 'voice-notes', icon: Mic, cover: P('voice') },
  { id: 'reports', slug: 'ai-reports', icon: Sparkles, cover: P('report') },
  { id: 'assistant', slug: 'ai-assistant', icon: Search, cover: P('house') },
  { id: 'pdf', slug: 'pdf-reports', icon: FileText, cover: P('tech') },
  { id: 'sharing', slug: 'customer-sharing', icon: Upload, cover: P('map') },
  { id: 'offline', slug: 'offline', icon: CloudOff, cover: P('outdoor') },
  { id: 'reviews', slug: 'reviews', icon: Star, cover: P('house') },
];

export const featureHref = (id: FeatureId) => `/features/${FEATURES.find((f) => f.id === id)!.slug}`;
export const featureBySlug = (slug: string) => FEATURES.find((f) => f.slug === slug);
export const feature = (id: FeatureId) => FEATURES.find((f) => f.id === id)!;

type Tone = 'success' | 'sage' | 'cream';
export interface Chip {
  icon: LucideIcon;
  tone: Tone;
}

/** One of the nine pages built on the shared template (W09–W17). */
export interface FeaturePageSpec {
  id: Exclude<FeatureId, 'reviews'>;
  /** 'phones' = two phones; 'browser' = the customer's report page in a browser plus a phone (W16). */
  hero: 'phones' | 'browser';
  chips: [Chip, Chip];
  /** The four "How it works" photos. */
  steps: [string, string, string, string];
  /** Icons of the six capability cards; [tagAt] gets the small green tag. */
  caps: [LucideIcon, LucideIcon, LucideIcon, LucideIcon, LucideIcon, LucideIcon];
  tagAt: number;
  /** 'shots' = four phones with captions; 'voice' = the voice → report demo; 'chat' = the AI chat window. */
  app: 'shots' | 'voice' | 'chat';
  appIcons?: [LucideIcon, LucideIcon, LucideIcon, LucideIcon];
  related: [FeatureId, FeatureId, FeatureId];
  /** Use cases show how many ready checklists each trade has (W11). */
  checklistCounts?: boolean;
}

export const PAGES: FeaturePageSpec[] = [
  {
    id: 'jobs',
    hero: 'phones',
    chips: [
      { icon: UserCheck, tone: 'success' },
      { icon: Clock, tone: 'cream' },
    ],
    steps: [P('clinic'), P('map'), P('tech'), P('report')],
    caps: [Plus, Users, Clock, HomeIcon, MapPin, Briefcase],
    tagAt: 1,
    app: 'shots',
    appIcons: [Plus, Users, HomeIcon, Clock],
    related: ['evidence', 'checklists', 'offline'],
  },
  {
    id: 'evidence',
    hero: 'phones',
    chips: [
      { icon: ImageIcon, tone: 'sage' },
      { icon: Clock, tone: 'cream' },
    ],
    steps: [P('clinic'), '/img/compare-before.webp', P('tech'), '/img/compare-after.webp'],
    caps: [Clock, Briefcase, ImageIcon, WifiOff, Fingerprint, Search],
    tagAt: 0,
    app: 'shots',
    appIcons: [ListChecks, Camera, ImageIcon, FileText],
    related: ['checklists', 'reports', 'sharing'],
  },
  {
    id: 'checklists',
    hero: 'phones',
    chips: [
      { icon: CircleHelp, tone: 'cream' },
      { icon: Camera, tone: 'sage' },
    ],
    steps: [P('indoor'), P('clinic'), P('tech'), P('report')],
    caps: [BookOpen, Camera, ListChecks, Smartphone, Languages, ShieldCheck],
    tagAt: 1,
    app: 'shots',
    appIcons: [Briefcase, ListChecks, CircleCheck, FileText],
    related: ['evidence', 'reports', 'jobs'],
    checklistCounts: true,
  },
  {
    id: 'voice',
    hero: 'phones',
    chips: [
      { icon: Mic, tone: 'sage' },
      { icon: Languages, tone: 'cream' },
    ],
    steps: [P('voice'), P('tech'), P('phonecam'), P('report')],
    caps: [Mic, ShieldCheck, Languages, Globe, RotateCcw, WifiOff],
    tagAt: 1,
    app: 'voice',
    related: ['reports', 'evidence', 'checklists'],
  },
  {
    id: 'reports',
    hero: 'phones',
    chips: [
      { icon: ImageIcon, tone: 'sage' },
      { icon: Languages, tone: 'cream' },
    ],
    steps: [P('phonecam'), P('voice'), P('report'), P('house')],
    caps: [Sparkles, Link2, Mic, Globe, TriangleAlert, UserCheck],
    tagAt: 1,
    app: 'voice',
    related: ['voice', 'evidence', 'sharing'],
  },
  {
    id: 'assistant',
    hero: 'phones',
    chips: [
      { icon: FileText, tone: 'success' },
      { icon: Search, tone: 'sage' },
    ],
    steps: [P('phonecam'), P('clinic'), P('tech'), P('report')],
    caps: [MessageCircle, Link2, Hash, Languages, ShieldCheck, Lock],
    tagAt: 1,
    app: 'chat',
    related: ['reports', 'jobs', 'pdf'],
  },
  {
    id: 'pdf',
    hero: 'phones',
    chips: [
      { icon: FileText, tone: 'cream' },
      { icon: CircleCheck, tone: 'success' },
    ],
    steps: [P('tech'), P('phonecam'), P('clinic'), P('report')],
    caps: [ImageIcon, Palette, ListChecks, Globe, Hash, Download],
    tagAt: 1,
    app: 'shots',
    appIcons: [Sparkles, UserCheck, Eye, Upload],
    related: ['reports', 'sharing', 'evidence'],
  },
  {
    id: 'sharing',
    hero: 'browser',
    chips: [
      { icon: MessageCircle, tone: 'sage' },
      { icon: CircleCheck, tone: 'success' },
    ],
    steps: [P('clinic'), P('phonecam'), P('report'), P('house')],
    caps: [Lock, Smartphone, CircleCheck, Eye, Clock, Download],
    tagAt: 1,
    app: 'shots',
    appIcons: [UserCheck, Upload, Eye, CircleCheck],
    related: ['pdf', 'reports', 'jobs'],
  },
  {
    id: 'offline',
    hero: 'phones',
    chips: [
      { icon: Smartphone, tone: 'cream' },
      { icon: RefreshCw, tone: 'success' },
    ],
    steps: [P('outdoor'), P('tech'), P('phonecam'), P('report')],
    caps: [Briefcase, RefreshCw, ShieldCheck, Bell, Smartphone, Download],
    tagAt: 1,
    app: 'shots',
    appIcons: [WifiOff, Camera, Clock, RefreshCw],
    related: ['evidence', 'jobs', 'voice'],
  },
];

export const page = (id: FeatureId) => PAGES.find((p) => p.id === id);

/** W31 Reviews & follow-ups. */
export const REVIEW_ICONS = {
  steps: [Upload, Bell, Phone] as const,
  caps: [Star, Bell, Phone, TriangleAlert, Users, MessageSquareReply] as const,
};
