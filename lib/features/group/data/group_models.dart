import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_models.freezed.dart';
part 'group_models.g.dart';

/// 그룹 안에서의 역할. 방장은 마지막 한 명이 아니면 넘기기 전에 나갈 수 없다.
enum MemberRole {
  @JsonValue('owner')
  owner,
  @JsonValue('member')
  member,
  unknown,
}

/// 선언 항목의 현재 상태.
///
/// `deferred` 는 아침에 약속했지만 다른 날로 미룬 것이다. 선언에서 빠져나갔어도
/// 기록은 남는다 — 미달성을 숨기지 않는 게 이 앱의 방식이다.
enum DeclarationItemStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('done')
  done,
  @JsonValue('deferred')
  deferred,
  @JsonValue('skipped')
  skipped,
  unknown,
}

/// 오늘 그룹이 연속 기록을 이어 가는 중인지.
enum GroupStreakStatus {
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('success')
  success,
  @JsonValue('broken')
  broken,
  unknown,
}

/// 서버 화이트리스트. 이 넷 밖의 값은 보내지 않는다.
enum ReactionType {
  @JsonValue('fire')
  fire,
  @JsonValue('clap')
  clap,
  @JsonValue('heart')
  heart,
  @JsonValue('muscle')
  muscle,
}

/// 랭킹 기간. **달력 기준**이다 — 통계 탭의 "최근 7일" 과 규칙이 다르다.
/// 여럿이 같은 순위표를 보므로 경계가 사람마다 달라지면 안 된다.
enum RankingPeriod {
  @JsonValue('week')
  week,
  @JsonValue('month')
  month,
  @JsonValue('all')
  all,
}

extension MemberRoleX on MemberRole {
  bool get isOwner => this == MemberRole.owner;

  String get label => switch (this) {
        MemberRole.owner => '방장',
        MemberRole.member => '구성원',
        MemberRole.unknown => '',
      };
}

extension DeclarationItemStatusX on DeclarationItemStatus {
  bool get isDone => this == DeclarationItemStatus.done;

  String get label => switch (this) {
        DeclarationItemStatus.pending => '아직',
        DeclarationItemStatus.done => '완료',
        DeclarationItemStatus.deferred => '미룸',
        DeclarationItemStatus.skipped => '건너뜀',
        DeclarationItemStatus.unknown => '',
      };
}

extension ReactionTypeX on ReactionType {
  String get wire => switch (this) {
        ReactionType.fire => 'fire',
        ReactionType.clap => 'clap',
        ReactionType.heart => 'heart',
        ReactionType.muscle => 'muscle',
      };

  /// 목록·집계 표시에 쓰는 글자. 이모지는 폰트에 따라 크기가 들쭉날쭉하지만
  /// 리액션은 네 종뿐이고 의미가 바로 읽혀서 여기서만 쓴다.
  String get glyph => switch (this) {
        ReactionType.fire => '🔥',
        ReactionType.clap => '👏',
        ReactionType.heart => '❤️',
        ReactionType.muscle => '💪',
      };

  static ReactionType? tryParse(String? wire) => switch (wire) {
        'fire' => ReactionType.fire,
        'clap' => ReactionType.clap,
        'heart' => ReactionType.heart,
        'muscle' => ReactionType.muscle,
        _ => null,
      };
}

extension RankingPeriodX on RankingPeriod {
  String get wire => switch (this) {
        RankingPeriod.week => 'week',
        RankingPeriod.month => 'month',
        RankingPeriod.all => 'all',
      };

  String get label => switch (this) {
        RankingPeriod.week => '이번 주',
        RankingPeriod.month => '이번 달',
        RankingPeriod.all => '전체',
      };
}

@freezed
abstract class DateRange with _$DateRange {
  const factory DateRange({
    @JsonKey(name: 'from') String? fromDate,
    @JsonKey(name: 'to') String? toDate,
  }) = _DateRange;

  factory DateRange.fromJson(Map<String, dynamic> json) =>
      _$DateRangeFromJson(json);
}

/// 피드·선언 목록에 붙는 작성자 정보.
@freezed
abstract class GroupUser with _$GroupUser {
  const factory GroupUser({
    @Default(0) int userId,
    @Default('') String nickname,
    String? profileImageUrl,
  }) = _GroupUser;

  factory GroupUser.fromJson(Map<String, dynamic> json) =>
      _$GroupUserFromJson(json);
}

/// `POST /groups`, `GET /groups`, `GET /groups/{id}`.
///
/// [unreadCount] · [lastActivityAt] 는 목록과 상세에만 담긴다 (생성 응답에는 없다).
@freezed
abstract class Group with _$Group {
  const factory Group({
    required int groupId,
    @Default('') String name,
    @Default(0) int ownerId,
    @Default(0) int memberCount,
    @Default(6) int maxMembers,

    /// 유효한 초대 코드. 재발급하면 이전 코드는 폐기된다.
    String? inviteCode,
    @Default(0) int groupStreak,
    String? lastStreakDate,
    @JsonKey(unknownEnumValue: MemberRole.unknown)
    @Default(MemberRole.unknown)
    MemberRole myRole,
    @Default(0) int unreadCount,
    DateTime? lastActivityAt,
    DateTime? createdAt,
  }) = _Group;

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
}

extension GroupX on Group {
  bool get isFull => memberCount >= maxMembers;

  bool get hasUnread => unreadCount > 0;
}

/// `POST /groups/{id}/invite`.
@freezed
abstract class GroupInvite with _$GroupInvite {
  const factory GroupInvite({
    @Default('') String inviteCode,
    DateTime? expiresAt,
  }) = _GroupInvite;

  factory GroupInvite.fromJson(Map<String, dynamic> json) =>
      _$GroupInviteFromJson(json);
}

/// `POST /uploads/presign`.
///
/// 사진은 서버를 거치지 않는다. 이 URL 로 클라이언트가 스토리지에 직접 올리고
/// [fileKey] 만 API 로 넘긴다.
@freezed
abstract class PresignResult with _$PresignResult {
  const factory PresignResult({
    @Default('') String uploadUrl,
    @Default('') String fileKey,
    @Default('image/jpeg') String contentType,
    DateTime? expiresAt,
  }) = _PresignResult;

  factory PresignResult.fromJson(Map<String, dynamic> json) =>
      _$PresignResultFromJson(json);
}

/// `GET /groups/{id}/members`.
///
/// [todayAchievementRate] 는 **선언한 항목 기준**이다. 선언하지 않았으면 0 이다.
@freezed
abstract class GroupMember with _$GroupMember {
  const factory GroupMember({
    @Default(0) int userId,
    @Default('') String nickname,
    String? profileImageUrl,
    @JsonKey(unknownEnumValue: MemberRole.unknown)
    @Default(MemberRole.unknown)
    MemberRole role,
    DateTime? joinedAt,
    @Default(false) bool todayDeclared,
    @Default(0.0) double todayAchievementRate,
    @Default(0) int streak,
  }) = _GroupMember;

  factory GroupMember.fromJson(Map<String, dynamic> json) =>
      _$GroupMemberFromJson(json);
}

/// 인증샷 한 장.
///
/// [imageUrl] 은 스토리지 버킷이 설정되지 않으면 null 이다. [fileKey] 는 언제나 온다.
@freezed
abstract class Proof with _$Proof {
  const factory Proof({
    required int postId,
    @Default(0) int declarationItemId,
    @Default(0) int groupId,
    @Default(0) int userId,
    String? date,
    @Default('') String fileKey,
    String? imageUrl,
    String? caption,
    DateTime? createdAt,
    @Default(0) int commentCount,

    /// 종류별 개수. 예: `{"fire": 2, "clap": 1}`
    @Default(<String, int>{}) Map<String, int> reactions,

    /// 내가 누른 리액션. 없으면 null.
    String? myReaction,
    GroupUser? user,
  }) = _Proof;

  factory Proof.fromJson(Map<String, dynamic> json) => _$ProofFromJson(json);
}

extension ProofX on Proof {
  ReactionType? get myReactionType => ReactionTypeX.tryParse(myReaction);

  int get reactionTotal =>
      reactions.values.fold(0, (sum, count) => sum + count);
}

/// 선언에 담긴 항목 하나.
@freezed
abstract class DeclarationItem with _$DeclarationItem {
  const factory DeclarationItem({
    required int declarationItemId,
    int? todoId,
    @Default('') String title,
    @JsonKey(unknownEnumValue: DeclarationItemStatus.unknown)
    @Default(DeclarationItemStatus.unknown)
    DeclarationItemStatus status,
    Proof? proof,
  }) = _DeclarationItem;

  factory DeclarationItem.fromJson(Map<String, dynamic> json) =>
      _$DeclarationItemFromJson(json);
}

/// `POST /groups/{id}/declarations` 의 응답.
@freezed
abstract class Declaration with _$Declaration {
  const factory Declaration({
    required int declarationId,
    @Default(0) int groupId,
    @Default(0) int userId,
    String? date,
    DateTime? lockedAt,
    @Default(<DeclarationItem>[]) List<DeclarationItem> items,
    @Default(0.0) double achievementRate,
  }) = _Declaration;

  factory Declaration.fromJson(Map<String, dynamic> json) =>
      _$DeclarationFromJson(json);
}

/// `GET /groups/{id}/declarations` 의 한 행.
///
/// **미선언 구성원도 [declarationId] 가 null 인 채로 함께 내려온다.**
/// 아직 선언 안 한 사람이 보이는 것 자체가 이 기능의 핵심이라 목록에서 빼지 않는다.
@freezed
abstract class DeclarationRow with _$DeclarationRow {
  const factory DeclarationRow({
    @Default(GroupUser()) GroupUser user,
    int? declarationId,
    String? date,
    DateTime? lockedAt,
    @Default(<DeclarationItem>[]) List<DeclarationItem> items,
    @Default(0.0) double achievementRate,
  }) = _DeclarationRow;

  factory DeclarationRow.fromJson(Map<String, dynamic> json) =>
      _$DeclarationRowFromJson(json);
}

extension DeclarationRowX on DeclarationRow {
  bool get declared => declarationId != null;

  int get doneCount => items.where((e) => e.status.isDone).length;
}

/// 피드에서 "못 한 항목" 으로 따로 내려오는 것.
@freezed
abstract class MissedItem with _$MissedItem {
  const factory MissedItem({
    @Default('') String title,
    @JsonKey(unknownEnumValue: DeclarationItemStatus.unknown)
    @Default(DeclarationItemStatus.unknown)
    DeclarationItemStatus status,
  }) = _MissedItem;

  factory MissedItem.fromJson(Map<String, dynamic> json) =>
      _$MissedItemFromJson(json);
}

/// `GET /groups/{id}/feed` 의 한 묶음. 사용자 한 명의 하루다.
@freezed
abstract class FeedEntry with _$FeedEntry {
  const factory FeedEntry({
    @Default(GroupUser()) GroupUser user,
    String? date,
    int? declarationId,
    @Default(0) int declaredCount,
    @Default(0) int doneCount,
    @Default(0.0) double achievementRate,
    @Default(<Proof>[]) List<Proof> posts,

    /// 약속했지만 못 한 것. 서버가 반드시 함께 내려준다.
    @Default(<MissedItem>[]) List<MissedItem> missedItems,
  }) = _FeedEntry;

  factory FeedEntry.fromJson(Map<String, dynamic> json) =>
      _$FeedEntryFromJson(json);
}

/// `GET /posts/{id}/comments`.
@freezed
abstract class PostComment with _$PostComment {
  const factory PostComment({
    required int commentId,
    @Default(0) int postId,
    @Default(GroupUser()) GroupUser user,
    @Default('') String content,
    DateTime? createdAt,
  }) = _PostComment;

  factory PostComment.fromJson(Map<String, dynamic> json) =>
      _$PostCommentFromJson(json);
}

/// `PUT /posts/{id}/reactions` 의 응답.
@freezed
abstract class ReactionTally with _$ReactionTally {
  const factory ReactionTally({
    @Default(0) int postId,
    @Default(<String, int>{}) Map<String, int> reactions,
    String? myReaction,
  }) = _ReactionTally;

  factory ReactionTally.fromJson(Map<String, dynamic> json) =>
      _$ReactionTallyFromJson(json);
}

/// 순위표의 한 줄. 동점은 같은 순위를 받고 다음 순위는 건너뛴다 (1, 2, 2, 4).
@freezed
abstract class RankingEntry with _$RankingEntry {
  const factory RankingEntry({
    @Default(0) int rank,
    @Default(0) int userId,
    @Default('') String nickname,
    String? profileImageUrl,
    @Default(0.0) double achievementRate,
    @Default(0) int declaredDays,
    @Default(0) int declaredItems,
    @Default(0) int completedItems,
    @Default(0) int streak,
  }) = _RankingEntry;

  factory RankingEntry.fromJson(Map<String, dynamic> json) =>
      _$RankingEntryFromJson(json);
}

/// `GET /groups/{id}/ranking`.
@freezed
abstract class GroupRanking with _$GroupRanking {
  const factory GroupRanking({
    @JsonKey(unknownEnumValue: RankingPeriod.week)
    @Default(RankingPeriod.week)
    RankingPeriod period,
    @Default(DateRange()) DateRange range,
    @Default(<RankingEntry>[]) List<RankingEntry> rankings,
    int? myRank,
  }) = _GroupRanking;

  factory GroupRanking.fromJson(Map<String, dynamic> json) =>
      _$GroupRankingFromJson(json);
}

/// `GET /groups/{id}/streak`.
///
/// 규칙: **선언한 구성원 전원이 선언 항목을 100% 끝낸 날**만 +1.
/// 미선언 구성원은 판정에서 빠지되 [membersTotal] 에는 들어간다.
@freezed
abstract class GroupStreak with _$GroupStreak {
  const factory GroupStreak({
    @Default(0) int groupStreak,
    String? lastSuccessDate,
    @JsonKey(unknownEnumValue: GroupStreakStatus.unknown)
    @Default(GroupStreakStatus.unknown)
    GroupStreakStatus todayStatus,
    @Default(0) int declaredMembersToday,
    @Default(0) int membersCompletedToday,
    @Default(0) int membersTotal,
  }) = _GroupStreak;

  factory GroupStreak.fromJson(Map<String, dynamic> json) =>
      _$GroupStreakFromJson(json);
}
