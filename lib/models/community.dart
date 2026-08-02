class Community {
  final String id;
  final String name;
  final String? description;
  final String? location;
  final String? bannerUrl;
  final String ownerId;
  final String visibility;
  final String verificationStatus;
  final bool isHidden;
  final int memberCount;
  final int eventCount;
  final String? category;
  final String? country;
  final String? state;
  final String? city;
  final String? contactEmail;
  final String? contactPhone;
  final String? instagramUrl;
  final String? facebookUrl;
  final String? twitterUrl;
  final String? linkedinUrl;
  final List<String>? tags;
  final String? rules;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Community({
    required this.id,
    required this.name,
    this.description,
    this.location,
    this.bannerUrl,
    required this.ownerId,
    this.visibility = 'public',
    this.verificationStatus = 'unverified',
    this.isHidden = false,
    this.memberCount = 0,
    this.eventCount = 0,
    this.category,
    this.country,
    this.state,
    this.city,
    this.contactEmail,
    this.contactPhone,
    this.instagramUrl,
    this.facebookUrl,
    this.twitterUrl,
    this.linkedinUrl,
    this.tags,
    this.rules,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Community.fromMap(Map<String, dynamic> map) => Community(
    id: map['id'] as String,
    name: map['name'] as String,
    description: map['description'] as String?,
    location: map['location'] as String?,
    bannerUrl: map['banner_url'] as String?,
    ownerId: map['owner_id'] as String,
    visibility: map['visibility'] as String? ?? 'public',
    verificationStatus: map['verification_status'] as String? ?? 'unverified',
    isHidden: map['is_hidden'] as bool? ?? false,
    memberCount: map['member_count'] as int? ?? 0,
    eventCount: map['event_count'] as int? ?? 0,
    category: map['category'] as String?,
    country: map['country'] as String?,
    state: map['state'] as String?,
    city: map['city'] as String?,
    contactEmail: map['contact_email'] as String?,
    contactPhone: map['contact_phone'] as String?,
    instagramUrl: map['instagram_url'] as String?,
    facebookUrl: map['facebook_url'] as String?,
    twitterUrl: map['twitter_url'] as String?,
    linkedinUrl: map['linkedin_url'] as String?,
    tags: map['tags'] != null ? List<String>.from(map['tags'] as List) : null,
    rules: map['rules'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    if (location != null) 'location': location,
    if (bannerUrl != null) 'banner_url': bannerUrl,
    'owner_id': ownerId,
    'visibility': visibility,
    'verification_status': verificationStatus,
    'is_hidden': isHidden,
    'member_count': memberCount,
    'event_count': eventCount,
    if (category != null) 'category': category,
    if (country != null) 'country': country,
    if (state != null) 'state': state,
    if (city != null) 'city': city,
    if (contactEmail != null) 'contact_email': contactEmail,
    if (contactPhone != null) 'contact_phone': contactPhone,
    if (instagramUrl != null) 'instagram_url': instagramUrl,
    if (facebookUrl != null) 'facebook_url': facebookUrl,
    if (twitterUrl != null) 'twitter_url': twitterUrl,
    if (linkedinUrl != null) 'linkedin_url': linkedinUrl,
    if (tags != null) 'tags': tags,
    if (rules != null) 'rules': rules,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
  };
}
