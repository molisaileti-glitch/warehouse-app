// [
//     {
//         "id": 2,
//         "name": "Stroman - Kuhlman",
//         "type": "AGRICULTURAL",
//         "region": 1,
//         "regionName": "Lake Elvaburgh",
//         "address": "438 Paolo Dale",
//         "registrationNumber": "5",
//         "phoneNumber": "279-896-1202",
//         "email": "Dahlia_Moore78@hotmail.com",
//         "tinNumber": "j",
//         "website": "https://blake.com",
//         "contactPersonName": "Kelley Mueller Sr.",
//         "contactPersonPhoneNumber": "709-426-0435",
//         "contactPersonEmail": "Royal.Murray64@hotmail.com",
//         "contactPersonTitle": "National Integration Associate",
//         "status": "ACTIVE"
//     },
//     {
//         "id": 3,
//         "name": "Schmitt - Powlowski",
//         "type": "AGRICULTURAL",
//         "region": 1,
//         "regionName": "Nadiaborough",
//         "address": "64724 Goyette Springs",
//         "registrationNumber": "o",
//         "phoneNumber": "223-512-3100",
//         "email": "Mckayla.Ernser@hotmail.com",
//         "tinNumber": "m",
//         "website": "http://reymundo.net",
//         "contactPersonName": "Krystal Sauer",
//         "contactPersonPhoneNumber": "344-415-5472",
//         "contactPersonEmail": "Jalon_Grimes25@hotmail.com",
//         "contactPersonTitle": "Future Program Technician",
//         "status": "ACTIVE"
//     }
// ]
class McuModel{
  final int id;
  final String name;
  final String type;
  final int region;
  final String regionName;
  final String address;
  final String registrationNumber;
  final String phoneNumber;
  final String email;
  final String tinNumber;
  final String website;
  final String contactPersonName;
  final String contactPersonPhoneNumber;
  final String contactPersonEmail;
  final String contactPersonTitle;
  final String status;

  McuModel({
    required this.id,
    required this.name,
    required this.type,
    required this.region,
    required this.regionName,
    required this.address,
    required this.registrationNumber,
    required this.phoneNumber,
    required this.email,
    required this.tinNumber,
    required this.website,
    required this.contactPersonName,
    required this.contactPersonPhoneNumber,
    required this.contactPersonEmail,
    required this.contactPersonTitle,
    required this.status
  });

  factory McuModel.fromJson(Map<String,dynamic> json){
    return McuModel(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      region: json['region'] as int,
      regionName: json['regionName'] as String,
      address: json['address'] as String,
      registrationNumber: json['registrationNumber'] as String,
      phoneNumber: json['phoneNumber'] as String,
      email: json['email'] as String,
      tinNumber: json['tinNumber'] as String,
      website: json['website'] as String,
      contactPersonName: json['contactPersonName'] as String,
      contactPersonPhoneNumber: json['contactPersonPhoneNumber'] as String,
      contactPersonEmail: json['contactPersonEmail'] as String,
      contactPersonTitle: json['contactPersonTitle'] as String,
      status: json['status'] as String
    );
  }

}