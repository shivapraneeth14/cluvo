// Legal policy content shown in the in-app consent dialogs and the consent
// gate. Mirrors apps/organizer-web/src/legal/* (separate codebases — keep in
// sync; CONSENT_VERSION is the drift guard: bump it whenever this content
// changes so the server can tell which version a user agreed to).

const String consentVersion = '2026-08-07';

class LegalSection {
  final String title;
  final String body;

  const LegalSection(this.title, this.body);
}

const List<LegalSection> privacyPolicySections = [
  LegalSection(
    '1. Information We Collect',
    'Email address, first and last name, and a username; profile and community '
    'photos you upload; content you create such as events, communities, posts, '
    'galleries, and reviews. When you buy event tickets, payment is processed '
    'through Razorpay — card and UPI details are entered directly in Razorpay\'s '
    'checkout and are not stored on our servers. We store the booking record, '
    'amount, payment status, and refund records. Organizer payouts are onboarded '
    'and paid out through Cashfree. If you sign in with Google, we receive your '
    'name and email address from your Google account. We also collect usage '
    'information such as events you wishlist or register for, notifications, '
    'event check-ins, and community membership.',
  ),
  LegalSection(
    '2. How We Use Information',
    'We use the information to provide and operate the Services: managing your '
    'account, communities, events and tickets; processing payments and refunds '
    'through Razorpay; hosting images through Cloudinary; sending notifications '
    'you have opted into; providing customer support; maintaining security and '
    'preventing fraud; and improving the Services.',
  ),
  LegalSection(
    '3. How We Share Information',
    'We do not sell your personal information. We share it only with service '
    'providers needed to operate the Services and as required by law: Razorpay '
    '(payment processing, refunds, fraud prevention), Cloudinary (image and '
    'media hosting), Google (Google Sign-in, if you choose it), Cashfree '
    '(payouts to community organizers), and Supabase (hosting, authentication, '
    'database, and realtime infrastructure). We may also disclose information '
    'to comply with legal obligations, to enforce our Terms, or in connection '
    'with a merger, acquisition, or transfer of assets.',
  ),
  LegalSection(
    '4. Retention and Deletion',
    'You can delete your account at any time from the app (Profile → Delete '
    'Account). When you do, we permanently remove your profile, wishlist, '
    'reviews, notifications, and community memberships. Registration and '
    'payment records and audit logs are retained for legal and financial '
    'purposes with your personal identifiers removed or unlinked. To request '
    'deletion, correction, or a copy of your data, email supp.cluvo@gmail.com.',
  ),
  LegalSection(
    '5. Children',
    'The Services are intended for users aged 13 and older and are not directed '
    'to children under 13. If you believe a child under 13 has provided us '
    'personal information, contact us and we will delete it.',
  ),
  LegalSection(
    '6. Security',
    'We use HTTPS encryption for all traffic and store data with access '
    'controls (row-level security) so users can only access their own data. No '
    'method of transmission or storage is completely secure, but we take '
    'reasonable measures to protect your information.',
  ),
  LegalSection(
    '7. Your Rights',
    'Depending on where you live, you may have rights to access, correct, '
    'delete, restrict, or object to our use of your personal information, and '
    'to data portability. You can exercise most of these from within the app; '
    'otherwise email supp.cluvo@gmail.com. You also have the right to lodge a '
    'complaint with your local data protection authority.',
  ),
  LegalSection(
    '8. International Transfers',
    'Our infrastructure providers (including Supabase) store and process data '
    'in multiple regions, which may include countries other than the one you '
    'live in. By using the Services you consent to such transfers.',
  ),
  LegalSection(
    '9. Changes to This Policy',
    'We may update this policy from time to time. Material changes will be '
    'posted with an updated date, and consent to a new version may be required '
    'on your next sign-in.',
  ),
  LegalSection(
    '10. Contact Us',
    'Questions or requests regarding this policy or your data: '
    'supp.cluvo@gmail.com',
  ),
];

const List<LegalSection> termsSections = [
  LegalSection(
    '1. Eligibility and Accounts',
    'You must be at least 13 years old to use the Services. You are responsible '
    'for keeping your account credentials confidential and for all activity '
    'that occurs under your account.',
  ),
  LegalSection(
    '2. Communities and Events',
    'Organizers create and manage communities and events, set capacities and '
    'prices, and are responsible for the accuracy of their listings and for the '
    'conduct of their events. Attendees register for events and receive tickets '
    'subject to the event\'s own terms.',
  ),
  LegalSection(
    '3. Payments, Tickets, and Refunds',
    'Payments for event tickets are processed by Razorpay. All purchases are '
    'for attendance at physical, in-person events. Refund eligibility and '
    'timing are set by the event organizer and processed through our payment '
    'provider; where we are able, we facilitate organizer-initiated refunds. We '
    'do not guarantee that any event will take place as listed.',
  ),
  LegalSection(
    '4. Acceptable Use',
    'You agree not to misuse the Services, including: violating any law; '
    'posting threatening, harassing, or infringing content; impersonating '
    'others; attempting to interfere with or break the security of the Services '
    'or our providers (including Supabase, Cloudinary, Razorpay, and Cashfree); '
    'reselling tickets or accounts in violation of an event\'s terms; or using '
    'the Services to conduct fraudulent transactions.',
  ),
  LegalSection(
    '5. Content and Intellectual Property',
    'You retain ownership of content you post. By posting, you grant us a '
    'non-exclusive license to host, display, and use that content solely to '
    'operate the Services. The Cluvo name, logos, and the Services themselves '
    'are protected by intellectual property laws and may not be copied or '
    'reused without our permission.',
  ),
  LegalSection(
    '6. Disclaimers and Limitation of Liability',
    'The Services are provided "as is" without warranties of any kind, express '
    'or implied. To the maximum extent permitted by law, we are not liable for '
    'indirect, incidental, special, or consequential damages, or for losses '
    'arising from events, organizers, other users, or payment providers. Our '
    'total liability is limited to the amount you paid to use the Services, if '
    'any, in the twelve months preceding the claim.',
  ),
  LegalSection(
    '7. Termination',
    'You may stop using the Services at any time and delete your account from '
    'within the app. We may suspend or terminate access if you violate these '
    'Terms.',
  ),
  LegalSection(
    '8. Governing Law and Changes',
    'These Terms are governed by the laws of India. We may update these Terms; '
    'material changes will be posted with an updated date. Continued use of the '
    'Services after changes constitutes acceptance.',
  ),
  LegalSection(
    '9. Contact Us',
    'Questions about these Terms: supp.cluvo@gmail.com',
  ),
];
