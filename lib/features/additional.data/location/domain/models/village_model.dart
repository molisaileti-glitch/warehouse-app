// "id": 1,
//         "name": "Muungano",
//         "ward": 1,
//         "wardName": "Kunduchi"

class VillageModel {
  final int id;
  final String name;
  final int ward;
  final String wardName;

  VillageModel({
    required this.id,
    required this.name,
    required this.ward,
    required this.wardName
  });

  // from Json Server to Model Object
  // response = {
  //   "id": 1,
  //   "name": "Muungano",
  // }
  // name = respone['name']
  //
  // function printMe(String name){}
  factory VillageModel.fromJsonToModelObject(Map<String, dynamic> json) {
    return VillageModel(
      id: json['id'] as int,
      name: json['name'] as String,
      ward: json['ward'] as int,
      wardName: json['wardName'] as String,
    );
  }

  // from Model Object to Json Server
  // Model Object = VillageModel(id: 1, name: "Muungano", ward: 1, wardName: "Kunduchi")
  // Map<String, dynamic> fromModelToJsonServer(VillageModel villageModel) {
  //   return {
  //     'id': villageModel.id,
  //     'name': villageModel.name,
  //     'ward': villageModel.ward,
  //     'wardName': villageModel.wardName,
  //   };
  // }
}