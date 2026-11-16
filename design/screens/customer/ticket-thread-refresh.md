# Screen spec: Support ticket thread refresh (part of screen 31)

- **Status:** ready for implementation. Version 1, 2026-11-10. **No decision needed.**
- **Owner:** ui-designer. **Implements:** flutter-customer-dev, in:
  - `customer_app/lib/features/support/presentation/support_controllers.dart` (`TicketThreadController`: a quiet refresh and a poll)
  - `customer_app/lib/features/support/presentation/ticket_screens.dart` (`TicketDetailScreen`: list direction, new-reply pill, stale line, closed-while-writing state, counter)
- **Sources:** `docs/03-customer-app.md` §2.11 (Help & support, ticket thread and reply). Audit finding CA-30 in `design/audits/2026-11-10-customer-app.md` (the rider app has the same gap, RA-22, and the staff console OC-26). Tokens are in `design/tokens/customer.tokens.json`; the token names below are its paths without the `customer.` prefix.
- **Rules:**
  - **Existing API only:** the ticket read the screen already uses (`support_tickets_retrieve`: the ticket, its messages oldest first, `can_reply`). No new endpoint and no socket.
  - Push for support replies waits for D-19, so until then this refresh is the only way a waiting customer sees a reply.
- **Who sees it:** a signed-in customer with the ticket thread open.

## 1. Refresh rules

| When | What happens |
|---|---|
| The screen opens | Load as today (skeleton, then the thread). |
| Every **15 s** (`motion.ticketPoll`) while the screen is the current route, the app is in the foreground, the device is online and the ticket isn't `CLOSED` | A **quiet** re-read (§2). |
| The app comes back to the foreground on this screen | One quiet re-read at once, then the 15 s rhythm. |
| The connection comes back (offline → online) | One quiet re-read at once. |
| Pull to refresh | As today, but through the quiet re-read (the thread stays on screen). |
| The customer is sending a reply | Polls pause until the send finishes (the send's answer already carries the new thread). |
| The ticket is `CLOSED`, or the screen is left | Polling stops. |

## 2. Quiet re-read

Add `refreshQuietly()` to `TicketThreadController`:
- Fetch the ticket. **On success**, replace the state only if something changed (message ids, the status, `can_reply`), so an unchanged poll doesn't rebuild the list.
- **On failure**, keep the current thread on screen (never the full-screen `ErrorRetryView`) and count consecutive failures. After **2 failures in a row**, show the stale line (§4). The next success clears it.
- **Photos:** a re-read brings new signed URLs for the same photos. Keep showing each photo with the URL it already has (key the widget by the photo's `key`, not its URL), and switch to the new URL only when the old one fails to load. That stops images from re-downloading every 15 s.

## 3. Thread layout and new replies

- **Newest at the bottom, and the screen opens there.** Build the list with `reverse: true` (data reversed), so it starts at the latest message and stays put when a new one is added at the bottom. Check with TalkBack that the reading order is still oldest to newest.
- **A new message arrives** (an id not seen before):
  - If the customer is at the bottom (within 80 dp): scroll it into view (a 200 ms animation, none under reduced motion).
  - If they have scrolled up to read older messages: don't move the list. Show a **"New reply ↓"** pill, centred just above the reply box: 48 dp high, `brand.primary` background with `brand.onPrimary` text (6.42:1), icon `arrow_downward`. A tap scrolls to the newest message and hides the pill.
  - Announce once per arrival batch: "New reply from Jivo support" (`SemanticsService.announce`), only for messages from support.
- **After the customer sends**, scroll to their new message (as the bottom case).

## 4. States

| State | What shows |
|---|---|
| First load | The existing skeleton. |
| First load failed | The existing `ErrorRetryView` (and a retry by itself when the connection returns). |
| Thread shown, polling | As today; the status chip in the header updates with each re-read. |
| Stale (2 failed polls in a row) | A one-line notice under the ticket header: "**Can't check for new replies right now.** Pull down to try again." `warning.tint` background, `text.primary` (15.62:1), icon `cloud_off` in `warning.fg`, 8 dp padding. |
| Ticket `RESOLVED` | The reply box stays (the server reopens the ticket on reply). Under it: "Replying reopens this ticket." (`bodySmall`, `text.secondary`, 8.91:1). |
| Ticket closed by support **while the customer is writing** (a re-read returns `can_reply: false` and the reply box has text) | The reply box is replaced by: "**This ticket was closed while you were writing.** Start a new ticket with your text?" and a 48 dp **Start a new ticket** button that opens the new-ticket screen with the typed text filled in (and the same order, when the ticket had one). The typed text is never thrown away. |
| Ticket closed, nothing typed | The existing closed note ("This ticket is closed. Create a new ticket if you still need help."). |
| Sending | The existing spinner in place of Send; polls paused. |

## 5. Reply box details

- **Character counter:** hidden below 900 characters; from 900, show "{count} / 1000" under the field (`bodySmall`, `text.secondary`; `danger.fg` at 1000). Today `counterText: ''` hides the limit until typing stops working.
- The polled data never touches the reply box or the picked photos (they are screen state).

## 6. Copy (new strings; suggested ARB keys)

| Key | Text |
|---|---|
| `ticketNewReplyPill` | New reply |
| `ticketNewReplyAnnounce` | New reply from Jivo support |
| `ticketStale` | Can't check for new replies right now. Pull down to try again. |
| `ticketReopenHint` | Replying reopens this ticket. |
| `ticketClosedWhileWriting` | This ticket was closed while you were writing. Start a new ticket with your text? |
| `ticketStartNewWithText` | Start a new ticket |
| `ticketCharCount` | {count} / {max} |

## 7. Performance and data

- One small GET every 15 s, only while the thread is on screen and the app is in the foreground: no background polling, nothing while offline.
- No rebuild when nothing changed (§2); photos aren't re-downloaded (§2).

## 8. Accessibility and text scaling

- **Contrast:** pill 6.42:1; stale line 15.62:1; hint 8.91:1.
- **Touch targets:** the pill and "Start a new ticket" are 48 dp.
- **Live announcements:** only new support messages (§3), never every poll.
- **Text scale 2.0** on 360×640: the stale line and the closed-while-writing text wrap; the pill keeps 48 dp and may wrap its label to 2 lines; the reply box stays visible above the keyboard. Add widget tests at 1.0×, 1.3× and 2.0× for the "new reply pill" and "closed while writing" states.

## 9. APIs required

None. Push for support replies stays a D-19 item.

## 10. Acceptance checks (for the developer and QA)

- [ ] With the thread open, a support reply sent from the Ops console appears within about 15 s without any tap.
- [ ] Polling stops when the screen is left, the app goes to the background, the device is offline, or the ticket is `CLOSED`; it re-reads once on resume and on reconnect.
- [ ] A failed poll keeps the thread on screen; two failures in a row show the stale line, and the next success hides it.
- [ ] The thread opens at the newest message; a new message scrolls into view when the customer is at the bottom, and shows the "New reply ↓" pill when they have scrolled up.
- [ ] Unchanged polls don't rebuild the list or re-download photos.
- [ ] A ticket closed while the customer is typing keeps the text and offers "Start a new ticket" with it filled in.
- [ ] The character counter appears from 900 characters.
- [ ] Widget tests at 1.0×, 1.3× and 2.0× on 360×640 pass with no overflow.
