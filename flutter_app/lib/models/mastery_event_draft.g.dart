// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mastery_event_draft.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMasteryEventDraftCollection on Isar {
  IsarCollection<MasteryEventDraft> get masteryEventDrafts => this.collection();
}

const MasteryEventDraftSchema = CollectionSchema(
  name: r'MasteryEventDraft',
  id: 8748408076725508336,
  properties: {
    r'competencyId': PropertySchema(
      id: 0,
      name: r'competencyId',
      type: IsarType.string,
    ),
    r'descriptorLevelId': PropertySchema(
      id: 1,
      name: r'descriptorLevelId',
      type: IsarType.string,
    ),
    r'deviceId': PropertySchema(
      id: 2,
      name: r'deviceId',
      type: IsarType.string,
    ),
    r'evidenceLocalIds': PropertySchema(
      id: 3,
      name: r'evidenceLocalIds',
      type: IsarType.stringList,
    ),
    r'localId': PropertySchema(
      id: 4,
      name: r'localId',
      type: IsarType.string,
    ),
    r'numericValue': PropertySchema(
      id: 5,
      name: r'numericValue',
      type: IsarType.double,
    ),
    r'observationNote': PropertySchema(
      id: 6,
      name: r'observationNote',
      type: IsarType.string,
    ),
    r'observedAt': PropertySchema(
      id: 7,
      name: r'observedAt',
      type: IsarType.dateTime,
    ),
    r'recordedAt': PropertySchema(
      id: 8,
      name: r'recordedAt',
      type: IsarType.dateTime,
    ),
    r'sourceType': PropertySchema(
      id: 9,
      name: r'sourceType',
      type: IsarType.string,
    ),
    r'studentId': PropertySchema(
      id: 10,
      name: r'studentId',
      type: IsarType.string,
    ),
    r'syncError': PropertySchema(
      id: 11,
      name: r'syncError',
      type: IsarType.string,
    ),
    r'syncStatus': PropertySchema(
      id: 12,
      name: r'syncStatus',
      type: IsarType.string,
    ),
    r'timestampConfidence': PropertySchema(
      id: 13,
      name: r'timestampConfidence',
      type: IsarType.string,
    ),
    r'timestampSource': PropertySchema(
      id: 14,
      name: r'timestampSource',
      type: IsarType.string,
    )
  },
  estimateSize: _masteryEventDraftEstimateSize,
  serialize: _masteryEventDraftSerialize,
  deserialize: _masteryEventDraftDeserialize,
  deserializeProp: _masteryEventDraftDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _masteryEventDraftGetId,
  getLinks: _masteryEventDraftGetLinks,
  attach: _masteryEventDraftAttach,
  version: '3.1.0+1',
);

int _masteryEventDraftEstimateSize(
  MasteryEventDraft object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.competencyId.length * 3;
  {
    final value = object.descriptorLevelId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.deviceId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.evidenceLocalIds.length * 3;
  {
    for (var i = 0; i < object.evidenceLocalIds.length; i++) {
      final value = object.evidenceLocalIds[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.localId.length * 3;
  {
    final value = object.observationNote;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sourceType.length * 3;
  bytesCount += 3 + object.studentId.length * 3;
  {
    final value = object.syncError;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.syncStatus.length * 3;
  bytesCount += 3 + object.timestampConfidence.length * 3;
  bytesCount += 3 + object.timestampSource.length * 3;
  return bytesCount;
}

void _masteryEventDraftSerialize(
  MasteryEventDraft object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.competencyId);
  writer.writeString(offsets[1], object.descriptorLevelId);
  writer.writeString(offsets[2], object.deviceId);
  writer.writeStringList(offsets[3], object.evidenceLocalIds);
  writer.writeString(offsets[4], object.localId);
  writer.writeDouble(offsets[5], object.numericValue);
  writer.writeString(offsets[6], object.observationNote);
  writer.writeDateTime(offsets[7], object.observedAt);
  writer.writeDateTime(offsets[8], object.recordedAt);
  writer.writeString(offsets[9], object.sourceType);
  writer.writeString(offsets[10], object.studentId);
  writer.writeString(offsets[11], object.syncError);
  writer.writeString(offsets[12], object.syncStatus);
  writer.writeString(offsets[13], object.timestampConfidence);
  writer.writeString(offsets[14], object.timestampSource);
}

MasteryEventDraft _masteryEventDraftDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MasteryEventDraft();
  object.competencyId = reader.readString(offsets[0]);
  object.descriptorLevelId = reader.readStringOrNull(offsets[1]);
  object.deviceId = reader.readStringOrNull(offsets[2]);
  object.evidenceLocalIds = reader.readStringList(offsets[3]) ?? [];
  object.id = id;
  object.localId = reader.readString(offsets[4]);
  object.numericValue = reader.readDouble(offsets[5]);
  object.observationNote = reader.readStringOrNull(offsets[6]);
  object.observedAt = reader.readDateTime(offsets[7]);
  object.recordedAt = reader.readDateTime(offsets[8]);
  object.sourceType = reader.readString(offsets[9]);
  object.studentId = reader.readString(offsets[10]);
  object.syncError = reader.readStringOrNull(offsets[11]);
  object.syncStatus = reader.readString(offsets[12]);
  object.timestampConfidence = reader.readString(offsets[13]);
  object.timestampSource = reader.readString(offsets[14]);
  return object;
}

P _masteryEventDraftDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringList(offset) ?? []) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readDouble(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readDateTime(offset)) as P;
    case 8:
      return (reader.readDateTime(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _masteryEventDraftGetId(MasteryEventDraft object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _masteryEventDraftGetLinks(
    MasteryEventDraft object) {
  return [];
}

void _masteryEventDraftAttach(
    IsarCollection<dynamic> col, Id id, MasteryEventDraft object) {
  object.id = id;
}

extension MasteryEventDraftQueryWhereSort
    on QueryBuilder<MasteryEventDraft, MasteryEventDraft, QWhere> {
  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MasteryEventDraftQueryWhere
    on QueryBuilder<MasteryEventDraft, MasteryEventDraft, QWhereClause> {
  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MasteryEventDraftQueryFilter
    on QueryBuilder<MasteryEventDraft, MasteryEventDraft, QFilterCondition> {
  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      competencyIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'competencyId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      competencyIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'competencyId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      competencyIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'competencyId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      competencyIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'competencyId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      competencyIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'competencyId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      competencyIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'competencyId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      competencyIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'competencyId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      competencyIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'competencyId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      competencyIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'competencyId',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      competencyIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'competencyId',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      descriptorLevelIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'descriptorLevelId',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      descriptorLevelIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'descriptorLevelId',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      descriptorLevelIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'descriptorLevelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      descriptorLevelIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'descriptorLevelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      descriptorLevelIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'descriptorLevelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      descriptorLevelIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'descriptorLevelId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      descriptorLevelIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'descriptorLevelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      descriptorLevelIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'descriptorLevelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      descriptorLevelIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'descriptorLevelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      descriptorLevelIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'descriptorLevelId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      descriptorLevelIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'descriptorLevelId',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      descriptorLevelIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'descriptorLevelId',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      deviceIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deviceId',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      deviceIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deviceId',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      deviceIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      deviceIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      deviceIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      deviceIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deviceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      deviceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      deviceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      deviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      deviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deviceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      deviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      deviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'evidenceLocalIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'evidenceLocalIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'evidenceLocalIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'evidenceLocalIds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'evidenceLocalIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'evidenceLocalIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsElementContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'evidenceLocalIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'evidenceLocalIds',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'evidenceLocalIds',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'evidenceLocalIds',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'evidenceLocalIds',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'evidenceLocalIds',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'evidenceLocalIds',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'evidenceLocalIds',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'evidenceLocalIds',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      evidenceLocalIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'evidenceLocalIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      localIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      localIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'localId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      localIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'localId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      localIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'localId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      localIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'localId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      localIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'localId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      localIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'localId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      localIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'localId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      localIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localId',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      localIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'localId',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      numericValueEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'numericValue',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      numericValueGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'numericValue',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      numericValueLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'numericValue',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      numericValueBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'numericValue',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observationNoteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'observationNote',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observationNoteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'observationNote',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observationNoteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'observationNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observationNoteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'observationNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observationNoteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'observationNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observationNoteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'observationNote',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observationNoteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'observationNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observationNoteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'observationNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observationNoteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'observationNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observationNoteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'observationNote',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observationNoteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'observationNote',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observationNoteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'observationNote',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'observedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'observedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'observedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      observedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'observedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      recordedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recordedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      recordedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'recordedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      recordedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'recordedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      recordedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'recordedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      sourceTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      sourceTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      sourceTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      sourceTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      sourceTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      sourceTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      sourceTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      sourceTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      sourceTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceType',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      sourceTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceType',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      studentIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'studentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      studentIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'studentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      studentIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'studentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      studentIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'studentId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      studentIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'studentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      studentIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'studentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      studentIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'studentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      studentIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'studentId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      studentIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'studentId',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      studentIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'studentId',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncErrorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'syncError',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncErrorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'syncError',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncErrorEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncErrorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'syncError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncErrorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'syncError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncErrorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'syncError',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncErrorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'syncError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncErrorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'syncError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncErrorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'syncError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncErrorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'syncError',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncErrorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncError',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncErrorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'syncError',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncStatusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncStatusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncStatusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncStatusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'syncStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncStatusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncStatusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'syncStatus',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      syncStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'syncStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampConfidenceEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestampConfidence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampConfidenceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestampConfidence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampConfidenceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestampConfidence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampConfidenceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestampConfidence',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampConfidenceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'timestampConfidence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampConfidenceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'timestampConfidence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampConfidenceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'timestampConfidence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampConfidenceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'timestampConfidence',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampConfidenceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestampConfidence',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampConfidenceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'timestampConfidence',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampSourceEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestampSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampSourceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestampSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampSourceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestampSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampSourceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestampSource',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampSourceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'timestampSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampSourceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'timestampSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampSourceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'timestampSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampSourceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'timestampSource',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampSourceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestampSource',
        value: '',
      ));
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterFilterCondition>
      timestampSourceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'timestampSource',
        value: '',
      ));
    });
  }
}

extension MasteryEventDraftQueryObject
    on QueryBuilder<MasteryEventDraft, MasteryEventDraft, QFilterCondition> {}

extension MasteryEventDraftQueryLinks
    on QueryBuilder<MasteryEventDraft, MasteryEventDraft, QFilterCondition> {}

extension MasteryEventDraftQuerySortBy
    on QueryBuilder<MasteryEventDraft, MasteryEventDraft, QSortBy> {
  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByCompetencyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'competencyId', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByCompetencyIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'competencyId', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByDescriptorLevelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descriptorLevelId', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByDescriptorLevelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descriptorLevelId', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localId', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByLocalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localId', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByNumericValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numericValue', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByNumericValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numericValue', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByObservationNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observationNote', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByObservationNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observationNote', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByObservedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observedAt', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByObservedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observedAt', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByRecordedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordedAt', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByRecordedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordedAt', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortBySourceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortBySourceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByStudentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'studentId', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByStudentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'studentId', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortBySyncError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncError', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortBySyncErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncError', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByTimestampConfidence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampConfidence', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByTimestampConfidenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampConfidence', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByTimestampSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampSource', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      sortByTimestampSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampSource', Sort.desc);
    });
  }
}

extension MasteryEventDraftQuerySortThenBy
    on QueryBuilder<MasteryEventDraft, MasteryEventDraft, QSortThenBy> {
  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByCompetencyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'competencyId', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByCompetencyIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'competencyId', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByDescriptorLevelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descriptorLevelId', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByDescriptorLevelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descriptorLevelId', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localId', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByLocalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localId', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByNumericValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numericValue', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByNumericValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numericValue', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByObservationNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observationNote', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByObservationNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observationNote', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByObservedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observedAt', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByObservedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observedAt', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByRecordedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordedAt', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByRecordedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordedAt', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenBySourceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenBySourceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByStudentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'studentId', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByStudentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'studentId', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenBySyncError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncError', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenBySyncErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncError', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByTimestampConfidence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampConfidence', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByTimestampConfidenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampConfidence', Sort.desc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByTimestampSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampSource', Sort.asc);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QAfterSortBy>
      thenByTimestampSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampSource', Sort.desc);
    });
  }
}

extension MasteryEventDraftQueryWhereDistinct
    on QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct> {
  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctByCompetencyId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'competencyId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctByDescriptorLevelId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'descriptorLevelId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctByDeviceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deviceId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctByEvidenceLocalIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'evidenceLocalIds');
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctByLocalId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctByNumericValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'numericValue');
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctByObservationNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'observationNote',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctByObservedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'observedAt');
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctByRecordedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recordedAt');
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctBySourceType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctByStudentId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'studentId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctBySyncError({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncError', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctBySyncStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncStatus', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctByTimestampConfidence({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestampConfidence',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MasteryEventDraft, MasteryEventDraft, QDistinct>
      distinctByTimestampSource({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestampSource',
          caseSensitive: caseSensitive);
    });
  }
}

extension MasteryEventDraftQueryProperty
    on QueryBuilder<MasteryEventDraft, MasteryEventDraft, QQueryProperty> {
  QueryBuilder<MasteryEventDraft, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MasteryEventDraft, String, QQueryOperations>
      competencyIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'competencyId');
    });
  }

  QueryBuilder<MasteryEventDraft, String?, QQueryOperations>
      descriptorLevelIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'descriptorLevelId');
    });
  }

  QueryBuilder<MasteryEventDraft, String?, QQueryOperations>
      deviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceId');
    });
  }

  QueryBuilder<MasteryEventDraft, List<String>, QQueryOperations>
      evidenceLocalIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'evidenceLocalIds');
    });
  }

  QueryBuilder<MasteryEventDraft, String, QQueryOperations> localIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localId');
    });
  }

  QueryBuilder<MasteryEventDraft, double, QQueryOperations>
      numericValueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'numericValue');
    });
  }

  QueryBuilder<MasteryEventDraft, String?, QQueryOperations>
      observationNoteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'observationNote');
    });
  }

  QueryBuilder<MasteryEventDraft, DateTime, QQueryOperations>
      observedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'observedAt');
    });
  }

  QueryBuilder<MasteryEventDraft, DateTime, QQueryOperations>
      recordedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recordedAt');
    });
  }

  QueryBuilder<MasteryEventDraft, String, QQueryOperations>
      sourceTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceType');
    });
  }

  QueryBuilder<MasteryEventDraft, String, QQueryOperations>
      studentIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'studentId');
    });
  }

  QueryBuilder<MasteryEventDraft, String?, QQueryOperations>
      syncErrorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncError');
    });
  }

  QueryBuilder<MasteryEventDraft, String, QQueryOperations>
      syncStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncStatus');
    });
  }

  QueryBuilder<MasteryEventDraft, String, QQueryOperations>
      timestampConfidenceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestampConfidence');
    });
  }

  QueryBuilder<MasteryEventDraft, String, QQueryOperations>
      timestampSourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestampSource');
    });
  }
}
