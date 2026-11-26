// @vitest-environment jsdom
/** Website page tests (step 6): the customer's report page (W27/W29) renders from the API and its actions call it. */
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import ReportPage from '../pages/report/ReportPage';
import type { PublicReport } from '../lib/types';

const photo = (id: string, stage: string) => ({ id, stage, url: `https://x/${id}.jpg`, thumb_url: null, taken_at: '2026-11-20T10:00:00Z' });

function report(over: Partial<PublicReport> = {}): PublicReport {
  return {
    number: 'R-1001', job_number: 'J-1001', title: 'AC service', customer: 'Green Valley Clinic',
    address: '12 Ring Road, Surat', technician: 'Ramesh Patel', approved_by: 'Asha Patel',
    approved_at: '2026-11-20T12:00:00Z', completed_at: '2026-11-20T11:00:00Z',
    company: { name: 'BrightAir', logo_url: null, phone: '+91 98250 22222' },
    praise: [{ rating: 5, comment: 'Spotless work', name: 'Anita', at: '2026-11-01T10:00:00Z' }],
    language: 'en', lang: 'en', languages: ['en'], summary: 'Cleaned the filters.', work_done: ['Cleaned filters'],
    advice: [], pairs: [{ subject: null, before: photo('b1', 'before'), after: photo('a1', 'after') }],
    photos: [photo('b1', 'before'), photo('a1', 'after')], checklists: [], photos_locked_at: '2026-11-20T12:00:00Z',
    acknowledged: null, link_expires_at: '2026-12-20T00:00:00Z', pdf_ready: true, fingerprint: null,
    review: null,
    ...over,
  };
}

let calls: { url: string; method: string; body: unknown }[] = [];

function serve(page: PublicReport) {
  calls = [];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string, init?: RequestInit) => {
      calls.push({ url, method: init?.method ?? 'GET', body: init?.body ? JSON.parse(String(init.body)) : null });
      const json = (init?.method ?? 'GET') === 'GET' ? page : { id: 'i1', received_at: '2026-11-26T10:00:00Z', review_id: 'v1', google_review_url: null };
      return new Response(JSON.stringify(json), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }),
  );
}

beforeEach(() => {
  window.history.replaceState({}, '', '/r/tok');
  localStorage.setItem('kn.lang', 'en');
  // jsdom has no IntersectionObserver (the scroll reveal)
  vi.stubGlobal('IntersectionObserver', class { observe() {} unobserve() {} disconnect() {} });
  vi.stubGlobal('matchMedia', (q: string) => ({ matches: false, media: q, addEventListener() {}, removeEventListener() {} }));
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('customer report page', () => {
  it('shows the report, Call with the company number and good reviews', async () => {
    serve(report());
    render(<ReportPage token="tok" />);
    expect(await screen.findAllByText(/BrightAir/)).not.toHaveLength(0);
    expect(screen.getByText('Cleaned the filters.')).toBeTruthy();
    const call = screen.getByRole('link', { name: /Call \+91 98250 22222/ });
    expect(call.getAttribute('href')).toBe('tel:+919825022222');
    expect(screen.getByText('“Spotless work”')).toBeTruthy();
  });

  it('has no Call button when the company set no number', async () => {
    serve(report({ company: { name: 'BrightAir', logo_url: null, phone: null }, praise: [] }));
    render(<ReportPage token="tok" />);
    await screen.findAllByText(/BrightAir/);
    expect(screen.queryByRole('link', { name: /^Call/ })).toBeNull();
  });

  it('"Book next service" sends when and the note', async () => {
    serve(report());
    render(<ReportPage token="tok" />);
    fireEvent.click(await screen.findByRole('button', { name: /Book next service/ }));
    fireEvent.click(screen.getByRole('button', { name: 'Next month' }));
    fireEvent.change(screen.getByRole('textbox', { name: /Anything they should know/ }), { target: { value: 'Before summer' } });
    fireEvent.click(screen.getByRole('button', { name: /Ask them to call me/ }));
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/public/reports/tok/service-request'))).toBe(true));
    const sent = calls.find((c) => c.url.endsWith('/service-request'))!;
    expect(sent.body).toEqual({ when: 'next_month', note: 'Before summer', contact: null });
    expect(await screen.findByText(/will call you to plan the next visit/)).toBeTruthy();
  });

  it('a rated job offers "Edit your review" and sends the change with PUT', async () => {
    window.history.replaceState({}, '', '/r/tok?rate=1');
    serve(
      report({
        review: {
          can_rate: false, rated: true, rating: 3, technician: 'Ramesh', positive_tags: ['on_time'],
          negative_tags: ['late'], can_edit: true, technician_rating: 3, tags: [], comment: 'Okay',
        },
      }),
    );
    render(<ReportPage token="tok" />);
    fireEvent.click(await screen.findByRole('button', { name: /Edit your review/ }));
    const send = await screen.findAllByRole('button', { name: /Send/ });
    fireEvent.click(send[send.length - 1]);
    await waitFor(() => expect(calls.some((c) => c.method === 'PUT' && c.url.endsWith('/public/reports/tok/review'))).toBe(true));
    expect(calls.find((c) => c.method === 'PUT')!.body).toMatchObject({ rating: 3, comment: 'Okay' });
  });
});
