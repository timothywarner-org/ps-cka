# CKA Exam Guide: Registration to Renewal

A complete guide to the Certified Kubernetes Administrator (CKA) exam lifecycle -- from purchasing and scheduling through exam day, results, digital badging, and renewal. All information is sourced from official CNCF, Linux Foundation, and PSI documentation.

Last updated: 2026-04-06

---

## Table of contents

1. [Exam overview](#exam-overview)
2. [Purchasing the exam](#purchasing-the-exam)
3. [Registration and account setup](#registration-and-account-setup)
4. [Scheduling your exam](#scheduling-your-exam)
5. [System and hardware requirements](#system-and-hardware-requirements)
6. [Network requirements](#network-requirements)
7. [Testing environment requirements](#testing-environment-requirements)
8. [ID and verification requirements](#id-and-verification-requirements)
9. [Pre-exam preparation checklist](#pre-exam-preparation-checklist)
10. [Exam day: check-in process](#exam-day-check-in-process)
11. [The exam environment](#the-exam-environment)
12. [Allowed resources during the exam](#allowed-resources-during-the-exam)
13. [Exam rules and conduct](#exam-rules-and-conduct)
14. [Technical issues during the exam](#technical-issues-during-the-exam)
15. [After the exam: scoring and results](#after-the-exam-scoring-and-results)
16. [Certification and digital badge](#certification-and-digital-badge)
17. [Certification verification](#certification-verification)
18. [Certification validity and renewal](#certification-validity-and-renewal)
19. [Retake policy](#retake-policy)
20. [Rescheduling and cancellation](#rescheduling-and-cancellation)
21. [No-show policy](#no-show-policy)
22. [Misconduct policy](#misconduct-policy)
23. [Accommodations for disabilities](#accommodations-for-disabilities)
24. [Exam bundles and discounts](#exam-bundles-and-discounts)
25. [Killer.sh exam simulator](#killersh-exam-simulator)
26. [Frequently asked questions](#frequently-asked-questions)
27. [Official resources and links](#official-resources-and-links)

---

## Exam overview

The Certified Kubernetes Administrator (CKA) exam is a performance-based certification developed by the Cloud Native Computing Foundation (CNCF) and administered by the Linux Foundation through PSI's online proctoring platform.

| Property | Detail |
| --- | --- |
| **Format** | Online, proctored, performance-based (100% practical) |
| **Duration** | 2 hours (120 minutes) |
| **Number of tasks** | Approximately 15-20 tasks |
| **Passing score** | 66% |
| **Kubernetes version** | v1.35 (updates within 4-8 weeks of new K8s releases) |
| **Delivery platform** | PSI Bridge Secure Browser |
| **Prerequisites** | None (no prior certification required) |
| **Certification validity** | 2 years from the date of passing |
| **Cost** | $445 (includes one free retake and two killer.sh sessions) |

The exam is entirely hands-on. There are no multiple-choice questions. Candidates must solve practical tasks by executing real commands against live Kubernetes clusters from a command-line terminal.

---

## Purchasing the exam

### Purchase options

| Option | Price | Includes |
| --- | --- | --- |
| **Exam only** | $445 | 2 exam attempts, 2 killer.sh simulator sessions, 12-month eligibility |
| **Exam + THRIVE-ONE subscription** | $625 | Everything above + unlimited e-learning courses, SkillCreds, premium microlearning (annual) |
| **Exam + LFS258 course** | $645 | Everything above + Kubernetes Fundamentals (LFS258) self-paced course |

### How to purchase

1. Go to the [CKA exam page](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/).
2. Select your preferred purchase option.
3. Complete the checkout process. You will need a Linux Foundation account (create one if you do not have one).
4. After purchase, the exam appears in your [My Portal](https://trainingportal.linuxfoundation.org/) dashboard.

### What is included in every purchase

- **Two exam attempts** (one initial attempt + one free retake if needed)
- **Two killer.sh exam simulator sessions** (each provides 36 hours of access with a unique set of 17 questions)
- **12-month eligibility window** to schedule and take both attempts

---

## Registration and account setup

### Linux Foundation ID

All exam activity is managed through your Linux Foundation (LF) account. If you do not have one, you will create it during purchase.

**Critical:** Your name in your LF account must match your government-issued photo ID exactly. Once you click "Start My Test" in PSI, the name is sent to PSI and cannot be changed. Mismatched names will prevent you from taking the exam.

### Post-purchase steps

1. Log in to [My Portal](https://trainingportal.linuxfoundation.org/).
2. Review and accept the **Linux Foundation Global Certification and Confidentiality Agreement**. You must accept this before scheduling. Refusal results in exam termination and fee forfeiture.
3. Verify your name matches your government-issued ID.
4. Confirm your operating system and testing location meet the requirements.
5. Schedule your exam (see next section).

---

## Scheduling your exam

### How to schedule

1. In My Portal, click the **Schedule** button next to your CKA exam.
2. You will be redirected to the **PSI Dashboard**.
3. Select your preferred language for proctor communications.
4. Click the exam name, review FAQs and test instructions, then select **Continue Booking**.
5. Optionally upload a photo ID at this stage (or complete this during check-in).
6. Select your country and time zone.
7. Choose your preferred date and time from available slots.

### Scheduling rules

- Exams can be scheduled **up to 90 days in advance**.
- A **24-hour lead time** is required -- the earliest you can schedule is the next day (to allow time for virtual machine preparation).
- You have **12 months from the date of purchase** to schedule and take both your exam and retake.
- Exams are available **24/7** across multiple time zones.

---

## System and hardware requirements

### Operating system

The exam uses the **PSI Secure Browser**, a Chrome-based application that downloads automatically when you launch the exam. Supported operating systems are published by PSI. Run the [PSI Online Proctoring System Check](https://syscheck.bridge.psiexams.com/) before your exam to verify compatibility.

**Important:** Virtual machines are explicitly prohibited, even if the compatibility check passes. Use a physical machine only.

### Hardware

| Requirement | Specification |
| --- | --- |
| **Monitor** | Single active monitor only (dual monitors not supported) |
| **Screen size** | 15 inches or larger recommended |
| **Screen resolution** | 1920 x 1080 (1080p) recommended |
| **RAM** | At least 50% available (reboot before exam) |
| **Webcam** | Movable/pannable webcam (built-in or external) |
| **Microphone** | Functional microphone (tested beforehand) |
| **Power** | Laptop must be plugged in during the exam |

### Software

- **Browser:** Google Chrome (latest version) recommended for scheduling. The PSI Secure Browser is provided at exam launch.
- **Admin privileges:** You must be able to install applications and manage processes.
- **Antivirus:** Disable or stop antivirus software during the exam.
- **Other applications:** No other applications or browser windows are permitted during the exam.

### Device recommendations

- Use a **personal device** rather than work-provided equipment.
- Work devices often have corporate security features (firewalls, endpoint protection, restricted admin access) that interfere with the PSI Secure Browser.
- If you must use a work device, ensure you have full administrative privileges and can disable security software.

---

## Network requirements

| Requirement | Detail |
| --- | --- |
| **Connection type** | Wired connection preferred; wireless acceptable but less reliable |
| **HTTPS access** | Must be able to reach AWS S3 endpoints (`https://*.s3.amazonaws.com/*`) |
| **Firewalls** | Corporate firewalls and proxies must not block S3 requests |
| **WebRTC** | WebRTC streaming must be allowed (check with your network administrator if on an employer network) |
| **Bandwidth** | Disable bandwidth-intensive services (file sync, BitTorrent, streaming, gaming) |
| **Isolation** | Ensure your connection is not shared with heavy users during the exam |

**Tip:** If possible, use a home network rather than a corporate network. Corporate networks frequently block the ports and protocols required by the PSI Secure Browser.

---

## Testing environment requirements

Your physical workspace must meet specific requirements. The proctor will ask you to show your workspace via webcam during check-in.

### Workspace

- **Private room** with walls and a door. No public spaces (coffee shops, open offices, libraries).
- **Clutter-free desk.** Remove all papers, books, writing implements, and electronic devices.
- **Clear walls.** No printed materials, whiteboards, or notes visible. Decorative items (artwork, photos) are acceptable.
- **Well-lit area.** Your face, hands, and workspace must be clearly visible on camera.
- **No backlighting.** Avoid bright lights or windows directly behind you.
- **Quiet environment.** No other people may be present (service animals as defined by the ADA are permitted).
- **Stay visible.** You must remain visible in the camera frame for the entire exam duration.

### Prohibited items on your desk

- Cell phones, tablets, smartwatches, or any electronic devices
- Papers, notebooks, textbooks, sticky notes
- Writing implements (pens, pencils, markers)
- Food (except clear liquids in a clear container)
- Headphones or earbuds (unless medically necessary)

---

## ID and verification requirements

### Accepted ID

You must present a **valid, unexpired government-issued physical photo ID** during check-in.

Acceptable forms of ID:

- Passport
- Driver's license
- National identification card
- Green card (permanent resident card)

### ID requirements

- Must include your **name, photograph, and signature**.
- The **first and last name** on the ID must match your Linux Foundation account name exactly.
- The ID must be a **physical document** (not a photocopy or digital image on a phone).
- The ID must be **unexpired**.

### Name mismatch

If your name does not match, you will not be able to proceed with the exam. Update your LF account name before exam day. Changes after clicking "Start My Test" are not possible.

---

## Pre-exam preparation checklist

Complete these steps before your exam date:

### 1. Accept the Global Certification Agreement

Review and accept the Linux Foundation Global Certification and Confidentiality Agreement in My Portal.

### 2. Verify your name

Confirm that your LF account name matches your government-issued photo ID exactly, including any non-Latin characters.

### 3. Run the system compatibility check

Visit the [PSI Online Proctoring System Check](https://syscheck.bridge.psiexams.com/) to verify your hardware, software, and network meet the requirements.

### 4. Take the PSI Remote Testing Tutorial

This optional but strongly recommended tutorial takes approximately 30 minutes and becomes available up to 150 minutes before your exam start time. It lets you:

- Practice with the PSI Secure Browser interface
- Learn to identify prohibited programs that may cause issues
- Familiarize yourself with the exam UI

### 5. Activate your killer.sh simulator sessions

Use your two included simulator sessions to practice. Each session provides 36 hours of access with a unique set of 17 questions. The simulator is intentionally harder than the real exam.

### 6. Review exam technical instructions

Familiarize yourself with the exam UI, keyboard shortcuts, and copy/paste behavior (detailed in the exam environment section below).

### 7. Prepare your workspace

Clear your desk, prepare your ID, ensure lighting is adequate, and close all applications on your computer.

### 8. Reboot your computer

Reboot before the exam to free up RAM and close background processes.

---

## Exam day: check-in process

### Launching the exam

1. The **Take Exam** button becomes available in My Portal **30 minutes before** your scheduled start time.
2. Click it to launch the PSI Secure Browser. Alternatively, log in directly at `https://test-takers.psiexams.com/linux/manage`.
3. You must start your exam **no later than 30 minutes after** the scheduled start time. If you do not start within this window, you are automatically marked as a no-show.

### Check-in sequence

The PSI Secure Browser will guide you through these steps:

1. **System scan.** The browser scans for unauthorized hardware (dual monitors) and software.
2. **Agreement screens.** Accept confidentiality and exam conduct agreements.
3. **ID upload.** Take a photo of your government-issued photo ID.
4. **Selfie.** Take a selfie for identity verification.
5. **Environment scan.** A Check-In Specialist will ask you to pan your webcam around your workspace and room via live chat.
6. **Proctor assignment.** Once your environment is approved, you are assigned a proctor who releases the exam.

**Wait time:** Assignment to a Check-In Specialist should not exceed 15 minutes. If it takes longer, use the **Live Chat** button in the PSI interface.

---

## The exam environment

### Interface layout

The exam runs inside the PSI Secure Browser, which provides:

- A **task panel** on the left with the current task description and requirements
- A **terminal** (Linux terminal emulator) on the right where you execute commands
- A **built-in Firefox browser** for accessing allowed documentation
- A **toolbar** with zoom controls, timer, and navigation

### Pre-configured tools

The exam environment comes with these tools pre-installed on SSH hosts:

| Tool | Description |
| --- | --- |
| `kubectl` | Kubernetes CLI, pre-configured for the current cluster |
| `k` | Alias for `kubectl` (pre-configured) |
| Bash autocompletion | Tab completion for kubectl commands and resource names |
| `yq` | YAML processing tool |
| `curl` | HTTP client for testing connectivity |
| `wget` | File download and HTTP testing |
| `man` | Manual pages |
| `vi` / `vim` | Text editor |

**Important:** These tools are available on the SSH hosts you connect to for each task. The base system does not have these tools.

### SSH and cluster access

- Each task specifies which cluster and host to use.
- Use `kubectl config use-context <cluster-name>` to switch to the correct cluster.
- SSH into designated hosts as instructed: `ssh <node-name>`.
- Use `sudo -i` for elevated privileges when needed.
- Type `exit` to return to the base system after each task.
- **Do NOT reboot the base node** -- the exam will not restart.
- **Nested SSH is not supported** (do not SSH from one host to another).

### Keyboard shortcuts

| Action | Terminal shortcut | Other applications |
| --- | --- | --- |
| Copy | `Ctrl+Shift+C` | `Ctrl+C` |
| Paste | `Ctrl+Shift+V` | `Ctrl+V` |
| Right-click context menu | Available | Available |
| Find in page (Firefox) | `Ctrl+F` | `Ctrl+F` |
| Locate cursor | `Ctrl+Alt+K` | `Ctrl+Alt+K` |
| Insert mode in vim | Press `i` | N/A |
| Exit insert mode in vim | Press `Esc` | N/A |

**Caution:** Use `Ctrl+Alt+W` instead of `Ctrl+W` in the terminal. `Ctrl+W` will close the Chrome tab.

**Caution:** The `INSERT` key is prohibited for security reasons. Use `i` in vim for insert mode.

### UI tips

- Use the **+** and **-** buttons in the PSI toolbar to zoom in and out.
- Double-click the Firefox header bar to maximize or minimize it.
- Drag the content panel border to resize the left sidebar.
- Maximize the PSI Secure Browser to full screen for the best experience.
- Toggle the video thumbnail to expand your display area.

---

## Allowed resources during the exam

During the exam, you may access documentation from these domains using the built-in Firefox browser:

| Domain | Content |
| --- | --- |
| **kubernetes.io/docs** | Kubernetes official documentation |
| **kubernetes.io/blog** | Kubernetes official blog |
| **helm.sh/docs** | Helm documentation |
| **gateway-api.sigs.k8s.io** | Gateway API documentation |

### Rules for documentation access

- You may open **one additional browser tab** for documentation alongside the exam interface.
- You may use **Ctrl+F** (Find in Page) within the browser.
- You may navigate freely within the allowed domains.
- You must **not navigate to any other website or domain**.
- You may use **man pages** and **distribution documentation** accessible from the terminal.
- You may use packages available within the exam distribution.

### Prohibited resources

- Internet browsing beyond the allowed domains
- Notes, study materials, or reference cards
- External devices (phones, tablets, second computers)
- Email clients
- Any resource not accessible from the terminal or allowed browser domains

---

## Exam rules and conduct

### General conduct

- Communicate only with the proctor during the exam.
- Remain visible to the webcam at all times.
- Do not read questions aloud.
- Do not write outside the exam console (no scratch paper).
- Follow all proctor instructions promptly.

### Food and drink

- No food is permitted.
- Clear liquids in a clear container are permitted.

### Devices

- No electronic devices on your body or within reach (phones, smartwatches, fitness trackers).
- No headphones or earbuds unless medically necessary and pre-approved.

### Zero-tolerance policy

The Linux Foundation enforces a zero-tolerance policy for exam misconduct. Violations may result in:

- Immediate exam termination
- Score revocation
- Restriction from future exam attempts
- All exam sessions are recorded and may be reviewed post-exam

---

## Technical issues during the exam

### Disconnection

If you are disconnected during the exam:

1. Re-launch the PSI Secure Browser from the PSI Dashboard "Access" button, or double-click the PSI Secure Browser application on your desktop.
2. You will reconnect to your exam session where you left off.
3. **The exam timer does not pause** during disconnection. No additional time is added.

### Proctor issues

If you experience issues with the proctor or check-in process:

- Use the **Live Chat** button within the PSI Secure Browser.
- Contact Linux Foundation training support at [trainingsupport.linuxfoundation.org](https://trainingsupport.linuxfoundation.org/).

### Post-exam

After the exam, uninstall the PSI Secure Browser. Reinstall fresh for any future exam attempts.

---

## After the exam: scoring and results

### Scoring

- Exams are **scored automatically**.
- There may be more than one correct way to complete a task. Any approach that produces the correct result receives credit.
- The Linux Foundation does **not** report performance on individual tasks and will not provide more detailed breakdowns.

### Results delivery

- Score reports are emailed **within 24 hours** of completing the exam.
- Results are also accessible in the **Results** section of My Portal.
- If you pass, your certificate and digital badge information will be included.
- If you do not pass, your retake option (if available) will be activated.

### Passing score

- **CKA: 66%** or above to pass.
- For comparison: CKAD requires 66%, CKS requires 67%.

---

## Certification and digital badge

### PDF certificate

Upon passing, you receive a PDF certificate accessible from My Portal. The certificate includes:

- Your full name
- Certification name (Certified Kubernetes Administrator)
- Date of certification
- Expiration date
- A unique Certificate ID number

### Digital badge via Credly

The Linux Foundation partners with **Credly** (now part of Pearson) to issue digital badges.

- After passing, you will receive an email from Credly with instructions to accept your badge.
- Badges can be shared on LinkedIn, Twitter/X, Facebook, and other social media.
- Badges can be added to email signatures and digital resumes.
- Each badge is uniquely linked to verification data on Credly -- clicking a badge verifies it.

**CKA badge on Credly:** [https://www.credly.com/org/the-linux-foundation/badge/cka-certified-kubernetes-administrator](https://www.credly.com/org/the-linux-foundation/badge/cka-certified-kubernetes-administrator)

**All Linux Foundation badges:** [https://www.credly.com/organizations/the-linux-foundation/badges](https://www.credly.com/organizations/the-linux-foundation/badges)

---

## Certification verification

### Verification tool

Anyone can verify the status of a CKA certification using the Linux Foundation Certification Verification Tool:

**URL:** [https://training.linuxfoundation.org/certification/verify](https://training.linuxfoundation.org/certification/verify)

To verify, enter:

- The **Certificate ID number** (found on the certificate)
- The **last name** listed on the certificate

The tool confirms whether the certification is active, expired, or invalid.

### Credly badge verification

Clicking on any Credly badge links directly to the badge holder's verified credential page, which shows:

- Certification name
- Issuing organization
- Date earned
- Expiration date
- Current status (active or expired)

---

## Certification validity and renewal

### Validity period

| When certified | Validity period |
| --- | --- |
| On or after April 1, 2024 | **2 years** from the date of passing |
| Before April 1, 2024 | **3 years** from the date of passing (grandfathered) |

The policy change from 3 years to 2 years took effect on April 1, 2024 (00:00 UTC). The Linux Foundation explained that the Kubernetes ecosystem evolves rapidly, with "an almost completely new exam every 24 months," necessitating more frequent recertification.

### Renewal process

To renew your CKA certification:

1. **Purchase a new CKA exam** (at the current price).
2. **Schedule and pass the exam** before your current certification expires.
3. Upon passing, your certification is renewed for an additional **2 years** from the date you pass.

There is no separate "renewal exam" -- you retake the full CKA exam with the current curriculum and Kubernetes version.

### Renewal timing

- You can renew at any time before your certification expires.
- If your certification expires before you renew, you lose your certified status. You must pass the exam again to become re-certified.
- The renewal date is based on when you pass the new exam, not when your previous certification was set to expire.

---

## Retake policy

### Included retake

Every CKA exam purchase includes **one free retake** if you do not pass on your first attempt.

### Retake rules

- The retake must be taken **within 12 months** of the original purchase date.
- There is **no enforced waiting period** between your first attempt and your retake. You can schedule the retake immediately.
- If you are marked as a no-show for your first attempt, you **forfeit** the retake and are not eligible for a refund.
- If your score is invalidated due to misconduct, you may lose retake eligibility.

### After using both attempts

If you do not pass on either attempt, you must purchase a new exam registration to try again.

---

## Rescheduling and cancellation

### Rescheduling

- You may reschedule your exam **up to 24 hours** before the scheduled start time.
- Access the "Cancel or Reschedule" option in My Portal's Exam Preparation Checklist, which redirects to PSI's scheduling site.
- Once fewer than 24 hours remain before your exam, **no modifications are allowed**.

### Cancellation

- You may cancel your exam reservation **up to 24 hours** before the scheduled start time.
- After cancellation, PSI sends a confirmation email and the Schedule button reactivates in My Portal for a new booking.
- Cancelling a reservation does **not** forfeit your exam attempt. You can reschedule within your 12-month eligibility window.

### Refund policy

Exam registration fees are subject to the Linux Foundation's refund policy. Check the [Exam Refund Policy](https://docs.linuxfoundation.org/tc-docs/certification/lf-handbook2/exam-refund-policy) for current terms.

---

## No-show policy

If you are a no-show for your scheduled exam:

- You **forfeit** your exam registration fees (no refund).
- You are **not eligible** for a retake.
- A "no-show" is defined as not starting your exam within **30 minutes** of the scheduled start time.

**This is one of the most punitive policies.** Set multiple reminders and log in early. The Take Exam button is available 30 minutes before your scheduled time.

---

## Misconduct policy

The Linux Foundation enforces a **zero-tolerance** misconduct policy. Exam misconduct includes:

- Communicating with anyone other than the proctor during the exam
- Using unauthorized resources (notes, devices, websites)
- Having another person present in the room
- Copying or sharing exam content
- Using a virtual machine to take the exam
- Any behavior identified as fraudulent through statistical analysis (data forensics)

### Consequences

- Immediate exam termination
- Score revocation (even after results are issued)
- Restriction from future exam attempts
- Sessions are recorded and subject to post-exam review

### Data forensics

The Linux Foundation employs statistical analyses of exam data to identify response patterns indicative of test fraud. If suspicious patterns are detected, scores may be invalidated even after results have been issued.

---

## Accommodations for disabilities

Candidates who require accommodations (extended time, assistive technology, breaks) should contact the Linux Foundation certification team before scheduling their exam.

- Service animals as defined by the ADA are permitted in the testing room.
- Medical devices (hearing aids, insulin pumps) may be permitted with prior approval.
- Contact: [trainingsupport.linuxfoundation.org](https://trainingsupport.linuxfoundation.org/)

---

## Exam bundles and discounts

The Linux Foundation offers several bundle options that include the CKA exam at a reduced effective price:

| Bundle | Price | Includes |
| --- | --- | --- |
| **CKA + CKAD** | Bundled price | Both exams with retakes and simulator access |
| **CKA + CKS** | Bundled price | Both exams with retakes and simulator access |
| **CKA + CKAD + CKS** | Bundled price | All three exams with retakes and simulator access |
| **CKA + THRIVE-ONE** | $625 | Exam + unlimited e-learning subscription |
| **CKA + LFS258** | $645 | Exam + Kubernetes Fundamentals course |

Check the [Linux Foundation certification catalog](https://training.linuxfoundation.org/certification-catalog/) for current prices. The Linux Foundation frequently offers promotional discounts during events like KubeCon, Black Friday, and Cyber Monday.

---

## Killer.sh exam simulator

### What is included

Every CKA exam purchase includes **two killer.sh simulator sessions**.

### How it works

- Each session provides **36 hours of access** from the time of activation.
- Each session contains a unique set of **17 questions** (the two sessions have different questions).
- The simulator runs in a browser and replicates the real exam environment.
- After the 36-hour window, you can still view the questions and solutions but cannot interact with the cluster.

### Difficulty level

The killer.sh simulator is **intentionally harder** than the real CKA exam. This is by design:

- A first-attempt score of **40-50%** on killer.sh is normal.
- A score of **90%+** on killer.sh indicates strong readiness for the real exam.
- Use the gap between sessions to study topics you struggled with.

### Activation

- Activate simulators from the **Exam Preparation Checklist** in My Portal.
- Each session starts its 36-hour timer immediately upon activation. Plan accordingly.
- Do not activate both sessions at the same time. Use the first session, study, then activate the second session closer to your exam date.

---

## Frequently asked questions

### Can I use bookmarks during the exam?

You can navigate freely within the allowed documentation domains using the built-in Firefox browser. Pre-loading bookmarks in Firefox is not guaranteed since the exam uses a clean PSI Secure Browser environment.

### What happens if my internet drops during the exam?

You can reconnect by re-launching the PSI Secure Browser. However, the timer does not pause and no additional time is added.

### Can I use an external keyboard or mouse?

Yes, external keyboards and mice are permitted.

### Can I take the exam on a Mac?

Yes, but Mac users may need to grant the PSI Secure Browser access to the microphone and camera in System Settings > Privacy & Security.

### Can I take the exam on Linux?

Yes. Check the PSI system requirements for supported Linux distributions. Linux-specific troubleshooting guides are available from PSI.

### How long do I have to schedule after purchasing?

You have 12 months from the date of purchase to schedule and take both your exam and retake.

### Can I take the exam in a language other than English?

The exam tasks are in English, but you can select your preferred language for proctor communications and PSI interface instructions during scheduling.

### What if I need to use the restroom during the exam?

There is no official break policy. The timer does not pause. If you must leave, inform the proctor via live chat. Leaving the camera frame without notice may be flagged as misconduct.

### Are notes from the exam allowed?

No. You may not take notes outside the exam console, and you may not record, photograph, or share any exam content. This is strictly enforced.

---

## Official resources and links

### Linux Foundation

- [CKA Exam Registration](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/)
- [My Portal (exam management)](https://trainingportal.linuxfoundation.org/)
- [Candidate Handbook](https://docs.linuxfoundation.org/tc-docs/certification/lf-handbook2)
- [CKA and CKAD Exam Tips](https://docs.linuxfoundation.org/tc-docs/certification/tips-cka-and-ckad)
- [CKA, CKAD, CKS FAQ](https://docs.linuxfoundation.org/tc-docs/certification/faq-cka-ckad-cks)
- [Exam Scheduling and Rescheduling](https://docs.linuxfoundation.org/tc-docs/certification/lf-handbook2/scheduling-or-rescheduling-an-exam)
- [Exam Refund Policy](https://docs.linuxfoundation.org/tc-docs/certification/lf-handbook2/exam-refund-policy)
- [Certification Verification Tool](https://training.linuxfoundation.org/certification/verify)
- [Certification Policy Change 2024](https://training.linuxfoundation.org/certification-policy-change-2024/)
- [Certification Catalog](https://training.linuxfoundation.org/certification-catalog/)
- [Training Support](https://trainingsupport.linuxfoundation.org/)

### CNCF

- [CKA Curriculum v1.35](https://github.com/cncf/curriculum)
- [CNCF CKA Page](https://www.cncf.io/training/certification/cka/)

### PSI

- [PSI System Compatibility Check](https://syscheck.bridge.psiexams.com/)
- [PSI Test-Taker Dashboard](https://test-takers.psiexams.com/linux/manage)

### Allowed documentation (accessible during exam)

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes Blog](https://kubernetes.io/blog/)
- [Helm Documentation](https://helm.sh/docs/)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)

### Exam simulator

- [killer.sh](https://killer.sh/)

### Digital badges

- [Credly -- CKA Badge](https://www.credly.com/org/the-linux-foundation/badge/cka-certified-kubernetes-administrator)
- [Credly -- All Linux Foundation Badges](https://www.credly.com/organizations/the-linux-foundation/badges)
