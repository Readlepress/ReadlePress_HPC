// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_conflict.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSyncConflictCollection on Isar {
  IsarCollection<SyncConflict> get syncConflicts => this.collection();
}

const SyncConflictSchema = CollectionSchema(
  name: r'SyncConflict',
  id: -8770548852093850888,
  properties: {
    r'conflictType': PropertySchema(
      id: 0,
      name: r'conflictType',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'deviceVersionJson': PropertySchema(
      id: 2,
      name: r'deviceVersionJson',
      type: IsarType.string,
    ),
    r'draftLocalId': PropertySchema(
      id: 3,
      name: r'draftLocalId',
      type: IsarType.string,
    ),
    r'existingEventId': PropertySchema(
      id: 4,
      name: r'existingEventId',
      type: IsarType.string,
    ),
    r'resolution': PropertySchema(
      id: 5,
      name: r'resolution',
      type: IsarType.string,
    ),
    r'resolvedAt': PropertySchema(
      id: 6,
      name: r'resolvedAt',
      type: IsarType.dateTime,
    ),
    r'resolvedBy': PropertySchema(
      id: 7,
      name: r'resolvedBy',
      type: IsarType.string,
    ),
    r'serverDraftId': PropertySchema(
      id: 8,
      name: r'serverDraftId',
      type: IsarType.string,
    ),
    r'serverVersionJson': PropertySchema(
      id: 9,
      name: r'serverVersionJson',
      type: IsarType.string,
    )
  },
  estimateSize: _syncConflictEstimateSize,
  serialize: _syncConflictSerialize,
  deserialize: _syncConflictDeserialize,
  deserializeProp: _syncConflictDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _syncConflictGetId,
  getLinks: _syncConflictGetLinks,
  attach: _syncConflictAttach,
  version: '3.1.0+1',
);

int _syncConflictEstimateSize(
  SyncConflict object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.conflictType.length * 3;
  bytesCount += 3 + object.deviceVersionJson.length * 3;
  bytesCount += 3 + object.draftLocalId.length * 3;
  {
    final value = object.existingEventId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.resolution;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.resolvedBy;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.serverDraftId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.serverVersionJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _syncConflictSerialize(
  SyncConflict object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.conflictType);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.deviceVersionJson);
  writer.writeString(offsets[3], object.draftLocalId);
  writer.writeString(offsets[4], object.existingEventId);
  writer.writeString(offsets[5], object.resolution);
  writer.writeDateTime(offsets[6], object.resolvedAt);
  writer.writeString(offsets[7], object.resolvedBy);
  writer.writeString(offsets[8], object.serverDraftId);
  writer.writeString(offsets[9], object.serverVersionJson);
}

SyncConflict _syncConflictDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SyncConflict();
  object.conflictType = reader.readString(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.deviceVersionJson = reader.readString(offsets[2]);
  object.draftLocalId = reader.readString(offsets[3]);
  object.existingEventId = reader.readStringOrNull(offsets[4]);
  object.id = id;
  object.resolution = reader.readStringOrNull(offsets[5]);
  object.resolvedAt = reader.readDateTimeOrNull(offsets[6]);
  object.resolvedBy = reader.readStringOrNull(offsets[7]);
  object.serverDraftId = reader.readStringOrNull(offsets[8]);
  object.serverVersionJson = reader.readStringOrNull(offsets[9]);
  return object;
}

P _syncConflictDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _syncConflictGetId(SyncConflict object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _syncConflictGetLinks(SyncConflict object) {
  return [];
}

void _syncConflictAttach(
    IsarCollection<dynamic> col, Id id, SyncConflict object) {
  object.id = id;
}

extension SyncConflictQueryWhereSort
    on QueryBuilder<SyncConflict, SyncConflict, QWhere> {
  QueryBuilder<SyncConflict, SyncConflict, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SyncConflictQueryWhere
    on QueryBuilder<SyncConflict, SyncConflict, QWhereClause> {
  QueryBuilder<SyncConflict, SyncConflict, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<SyncConflict, SyncConflict, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterWhereClause> idBetween(
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

extension SyncConflictQueryFilter
    on QueryBuilder<SyncConflict, SyncConflict, QFilterCondition> {
  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      conflictTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conflictType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      conflictTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conflictType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      conflictTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conflictType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      conflictTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conflictType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      conflictTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conflictType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      conflictTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conflictType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      conflictTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conflictType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      conflictTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conflictType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      conflictTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conflictType',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      conflictTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conflictType',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      deviceVersionJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceVersionJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      deviceVersionJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deviceVersionJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      deviceVersionJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deviceVersionJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      deviceVersionJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deviceVersionJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      deviceVersionJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deviceVersionJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      deviceVersionJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deviceVersionJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      deviceVersionJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deviceVersionJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      deviceVersionJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deviceVersionJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      deviceVersionJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceVersionJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      deviceVersionJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deviceVersionJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      draftLocalIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'draftLocalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      draftLocalIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'draftLocalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      draftLocalIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'draftLocalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      draftLocalIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'draftLocalId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      draftLocalIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'draftLocalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      draftLocalIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'draftLocalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      draftLocalIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'draftLocalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      draftLocalIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'draftLocalId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      draftLocalIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'draftLocalId',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      draftLocalIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'draftLocalId',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      existingEventIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'existingEventId',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      existingEventIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'existingEventId',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      existingEventIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'existingEventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      existingEventIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'existingEventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      existingEventIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'existingEventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      existingEventIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'existingEventId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      existingEventIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'existingEventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      existingEventIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'existingEventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      existingEventIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'existingEventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      existingEventIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'existingEventId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      existingEventIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'existingEventId',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      existingEventIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'existingEventId',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition> idBetween(
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

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolutionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resolution',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolutionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resolution',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolutionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolution',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolutionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolution',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolutionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolution',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolutionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolution',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolutionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resolution',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolutionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resolution',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolutionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolution',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolutionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolution',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolutionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolution',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolutionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolution',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resolvedAt',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resolvedAt',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolvedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolvedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolvedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedByIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resolvedBy',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedByIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resolvedBy',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedByEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedByGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolvedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedByLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolvedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedByBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolvedBy',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedByStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resolvedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedByEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resolvedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedByContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolvedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedByMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolvedBy',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedByIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedBy',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      resolvedByIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolvedBy',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverDraftIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'serverDraftId',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverDraftIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'serverDraftId',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverDraftIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'serverDraftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverDraftIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'serverDraftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverDraftIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'serverDraftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverDraftIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'serverDraftId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverDraftIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'serverDraftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverDraftIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'serverDraftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverDraftIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'serverDraftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverDraftIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'serverDraftId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverDraftIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'serverDraftId',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverDraftIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'serverDraftId',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverVersionJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'serverVersionJson',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverVersionJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'serverVersionJson',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverVersionJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'serverVersionJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverVersionJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'serverVersionJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverVersionJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'serverVersionJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverVersionJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'serverVersionJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverVersionJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'serverVersionJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverVersionJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'serverVersionJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverVersionJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'serverVersionJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverVersionJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'serverVersionJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverVersionJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'serverVersionJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterFilterCondition>
      serverVersionJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'serverVersionJson',
        value: '',
      ));
    });
  }
}

extension SyncConflictQueryObject
    on QueryBuilder<SyncConflict, SyncConflict, QFilterCondition> {}

extension SyncConflictQueryLinks
    on QueryBuilder<SyncConflict, SyncConflict, QFilterCondition> {}

extension SyncConflictQuerySortBy
    on QueryBuilder<SyncConflict, SyncConflict, QSortBy> {
  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> sortByConflictType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conflictType', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      sortByConflictTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conflictType', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      sortByDeviceVersionJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceVersionJson', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      sortByDeviceVersionJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceVersionJson', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> sortByDraftLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftLocalId', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      sortByDraftLocalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftLocalId', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      sortByExistingEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'existingEventId', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      sortByExistingEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'existingEventId', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> sortByResolution() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolution', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      sortByResolutionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolution', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> sortByResolvedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      sortByResolvedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> sortByResolvedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedBy', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      sortByResolvedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedBy', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> sortByServerDraftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverDraftId', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      sortByServerDraftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverDraftId', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      sortByServerVersionJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverVersionJson', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      sortByServerVersionJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverVersionJson', Sort.desc);
    });
  }
}

extension SyncConflictQuerySortThenBy
    on QueryBuilder<SyncConflict, SyncConflict, QSortThenBy> {
  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> thenByConflictType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conflictType', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      thenByConflictTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conflictType', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      thenByDeviceVersionJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceVersionJson', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      thenByDeviceVersionJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceVersionJson', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> thenByDraftLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftLocalId', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      thenByDraftLocalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftLocalId', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      thenByExistingEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'existingEventId', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      thenByExistingEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'existingEventId', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> thenByResolution() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolution', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      thenByResolutionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolution', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> thenByResolvedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      thenByResolvedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> thenByResolvedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedBy', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      thenByResolvedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedBy', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy> thenByServerDraftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverDraftId', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      thenByServerDraftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverDraftId', Sort.desc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      thenByServerVersionJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverVersionJson', Sort.asc);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QAfterSortBy>
      thenByServerVersionJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverVersionJson', Sort.desc);
    });
  }
}

extension SyncConflictQueryWhereDistinct
    on QueryBuilder<SyncConflict, SyncConflict, QDistinct> {
  QueryBuilder<SyncConflict, SyncConflict, QDistinct> distinctByConflictType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conflictType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QDistinct>
      distinctByDeviceVersionJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deviceVersionJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QDistinct> distinctByDraftLocalId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'draftLocalId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QDistinct> distinctByExistingEventId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'existingEventId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QDistinct> distinctByResolution(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolution', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QDistinct> distinctByResolvedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedAt');
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QDistinct> distinctByResolvedBy(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedBy', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QDistinct> distinctByServerDraftId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serverDraftId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncConflict, SyncConflict, QDistinct>
      distinctByServerVersionJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serverVersionJson',
          caseSensitive: caseSensitive);
    });
  }
}

extension SyncConflictQueryProperty
    on QueryBuilder<SyncConflict, SyncConflict, QQueryProperty> {
  QueryBuilder<SyncConflict, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SyncConflict, String, QQueryOperations> conflictTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conflictType');
    });
  }

  QueryBuilder<SyncConflict, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<SyncConflict, String, QQueryOperations>
      deviceVersionJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceVersionJson');
    });
  }

  QueryBuilder<SyncConflict, String, QQueryOperations> draftLocalIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'draftLocalId');
    });
  }

  QueryBuilder<SyncConflict, String?, QQueryOperations>
      existingEventIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'existingEventId');
    });
  }

  QueryBuilder<SyncConflict, String?, QQueryOperations> resolutionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolution');
    });
  }

  QueryBuilder<SyncConflict, DateTime?, QQueryOperations> resolvedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedAt');
    });
  }

  QueryBuilder<SyncConflict, String?, QQueryOperations> resolvedByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedBy');
    });
  }

  QueryBuilder<SyncConflict, String?, QQueryOperations>
      serverDraftIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serverDraftId');
    });
  }

  QueryBuilder<SyncConflict, String?, QQueryOperations>
      serverVersionJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serverVersionJson');
    });
  }
}
