import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:team_app/features/verification/domain/entities/verification_enums.dart';
import 'package:team_app/features/verification/domain/entities/verification_submission.dart';
import 'package:team_app/features/verification/domain/services/verification_policy.dart';
import 'package:team_app/features/verification/domain/services/verification_validator.dart';

VerificationFile file(VerificationDocumentType t, {String name = 'a.jpg', int size = 100}) => VerificationFile(
      documentType: t,
      fileName: name,
      bytes: Uint8List(size),
      mimeType: 'image/jpeg',
    );

VerificationSubmission sub(
  VerificationTargetType type,
  Map<String, dynamic> data,
  List<VerificationFile> files, {
  bool isAgency = false,
}) =>
    VerificationSubmission(targetType: type, targetId: 'x', submittedData: data, files: files, isAgency: isAgency);

void main() {
  const id = VerificationDocumentType.identity;
  const own = VerificationDocumentType.ownershipDocument;
  const pro = VerificationDocumentType.professionalDocument;
  const agency = VerificationDocumentType.agencyDocument;
  final person = {'fullName': 'Sana Trabelsi', 'phone': '+216 22 333 444'};

  test('valid user request', () {
    expect(VerificationValidator.validate(sub(VerificationTargetType.user, person, [file(id)])), isEmpty);
  });

  test('missing fields and missing document', () {
    final e = VerificationValidator.validate(sub(VerificationTargetType.user, {'fullName': 'A', 'phone': '12'}, []));
    expect(e.containsKey('fullName'), isTrue);
    expect(e.containsKey('phone'), isTrue);
    expect(e.containsKey('identity'), isTrue);
  });

  test('owner needs identity AND ownership document', () {
    final e = VerificationValidator.validate(sub(VerificationTargetType.owner, person, [file(id)]));
    expect(e.containsKey('ownership_document'), isTrue);
    expect(e.containsKey('identity'), isFalse);
    expect(VerificationValidator.validate(sub(VerificationTargetType.owner, person, [file(id), file(own)])), isEmpty);
  });

  test('agent: agency needs agency fields and document', () {
    final files = [file(id), file(pro)];
    expect(VerificationValidator.validate(sub(VerificationTargetType.agent, person, files)), isEmpty);
    final e = VerificationValidator.validate(sub(VerificationTargetType.agent, person, files, isAgency: true));
    expect(e.containsKey('agencyName'), isTrue);
    expect(e.containsKey('agencyAddress'), isTrue);
    expect(e.containsKey('agency_document'), isTrue);
    final ok = VerificationValidator.validate(sub(
      VerificationTargetType.agent,
      {...person, 'agencyName': 'TN Immo', 'agencyAddress': 'Avenue Habib Bourguiba'},
      [...files, file(agency)],
      isAgency: true,
    ));
    expect(ok, isEmpty);
  });

  test('property needs complete listing and ownership evidence', () {
    final data = {
      'propertyTitle': 'Duplex',
      'city': 'Ariana',
      'locationProvided': true,
      'listingInformationProvided': true,
      'photoCount': 3,
    };
    expect(VerificationValidator.validate(sub(VerificationTargetType.property, data, [file(own)])), isEmpty);
    final bad = VerificationValidator.validate(
        sub(VerificationTargetType.property, {...data, 'locationProvided': false, 'photoCount': 0}, [file(own)]));
    expect(bad.containsKey('property'), isTrue);
  });

  test('file rules: format, empty, size, count', () {
    expect(VerificationValidator.validate(sub(VerificationTargetType.user, person, [file(id, name: 'a.pdf')])).containsKey('identity'), isTrue);
    expect(VerificationValidator.validate(sub(VerificationTargetType.user, person, [file(id, size: 0)])).containsKey('identity'), isTrue);
    expect(
        VerificationValidator.validate(
            sub(VerificationTargetType.user, person, [file(id, size: VerificationPolicy.maxFileBytes + 1)])).containsKey('identity'),
        isTrue);
    final many = [for (var i = 0; i < 4; i++) file(id)];
    expect(VerificationValidator.validate(sub(VerificationTargetType.user, person, many)).containsKey('identity'), isTrue);
  });

  test('phone formatting is tolerated', () {
    expect(normalizePhone('+216 22-333.444'), '+21622333444');
  });
}
