# Contract: Canvas UI (accessible labels)

Playwright (Layer 2) finds controls **only** by these `AccessibleLabel` values, the same way a screen-reader
user would. Every listed control MUST set its `AccessibleLabel` exactly as written. Renaming a label is a
breaking change for the tests.

## Global
| Element | AccessibleLabel | Notes |
|---|---|---|
| Sign-in email input | `Email` | On the sign-in panel (Screen1) |
| Continue button | `Continue` | Signs in with the typed email |
| Sign-in error | `Sign-in error` | Invalid email format |
| Signed-in user name | `Signed in user` | Text: "Signed in as {Full Name}" |
| Sign out | `Sign out` | Back to the sign-in panel; clears identity and chat |
| Greeting | `Greeting` | "Good morning/afternoon/evening, {first name}" |
| Not-registered panel | `Not registered message` | Visible only when `varMe` is blank |
| Nav to Approvals | `Go to Approvals` | Visible only if the user has direct reports |
| Nav to Log Time | `Go to Log Time` | On the Approvals and Assistant screens |
| Nav to Assistant | `Go to Assistant` | On the Log Time and Approvals screens |

## Log Time screen (`Screen1`)
| Element | AccessibleLabel |
|---|---|
| Week total | `Week total hours` |
| Week progress bar | `Week progress` |
| This week's entries gallery | `This week entries` |
| Project picker | `Project` |
| Date picker | `Work date` |
| Hours input | `Hours` |
| Notes input | `Notes` |
| Save entry button | `Save entry` |
| Validation message | `Entry error` |
| Submit week button | `Submit week` |
| Edit entry (per row, Draft/Rejected) | `Edit entry` |
| Delete entry (per row, Draft) | `Delete entry` |
| Cancel edit | `Cancel edit` |

Each gallery row's text includes project name, date (yyyy-mm-dd), hours and status, so tests can assert on row text.

## Approvals screen (`Approvals`)
| Element | AccessibleLabel |
|---|---|
| Pending gallery | `Pending approvals` |
| Approve button (per row) | `Approve entry` |
| Reject button (per row) | `Reject entry` |
| Rejection comment input | `Rejection comment` |
| Confirm rejection button | `Confirm rejection` |
| Rejection error | `Rejection error` |

Each row's text includes the employee's full name, project, date, hours.

Visual styling of every element follows [ui-theme.md](./ui-theme.md).

## Assistant screen (`Assistant`)
| Element | AccessibleLabel |
|---|---|
| Chat gallery | `Chat messages` |
| Message input | `Message` |
| Send button | `Send` |
| New chat button | `New chat` |
| Thinking indicator (text) | `Assistant is thinking…` |
| Error panel retry | `Try again` |
| Suggested prompts | `Suggested question: {text}` |

Each chat row's text starts with "You: " or "Assistant: ".
