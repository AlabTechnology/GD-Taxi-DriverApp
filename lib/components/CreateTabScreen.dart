import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:taxi_driver/Services/RideService.dart';
import 'package:taxi_driver/model/CurrentRequestModel.dart';
import 'package:taxi_driver/model/RiderModel.dart';
import 'package:taxi_driver/screens/DashboardScreen.dart';
import 'package:taxi_driver/utils/Extensions/dataTypeExtensions.dart';
import '../main.dart';
import '../network/RestApis.dart';
import '../screens/RideDetailScreen.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/app_common.dart';
import 'package:http/http.dart' as http;

class CreateTabScreen extends StatefulWidget {
  final String? status;

  CreateTabScreen({this.status});

  @override
  CreateTabScreenState createState() => CreateTabScreenState();
}

class CreateTabScreenState extends State<CreateTabScreen> {
  ScrollController scrollController = ScrollController();
  OnRideRequest? servicesListData;
  RideService rideService = RideService();
  int currentPage = 1;
  int totalPage = 1;
  List<RiderModel> riderData = [];
  List<String> riderStatus = [COMPLETED, CANCELED];

  @override
  void initState() {
    super.initState();
    init();
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        if (currentPage != totalPage) {
          appStore.setLoading(true);
          currentPage++;
          setState(() {});

          init();
        }
      }
    });
    afterBuildCreated(() => appStore.setLoading(true));
  }

  void init() async {
    await getRiderRequestList(
            page: currentPage,
            status: widget.status==UPCOMING?SCHEDULED:widget.status,
            driverId: widget.status==SCHEDULED?0:sharedPref.getInt(USER_ID))
        .then((value) {
      appStore.setLoading(false);

      currentPage = value.pagination!.currentPage!;
      totalPage = value.pagination!.totalPages!;
      if (currentPage == 1) {
        riderData.clear();
      }
      riderData.addAll(value.data!);
      setState(() {});
    }).catchError((error, s) {
      appStore.setLoading(false);
      log(error.toString() + "FJkjfklsajfj::$s");
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }
  Future<bool> checkDriverStatus(int driverId) async {
    const String url = "${DOMAIN_URL}/api/current-driver-status";
    Map<String, String> header = {
      HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      HttpHeaders.cacheControlHeader: 'no-cache',
      HttpHeaders.acceptHeader: 'application/json; charset=utf-8',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Allow-Origin': '*',
    };
    if (appStore.isLoggedIn) {
      header.putIfAbsent(HttpHeaders.authorizationHeader,
              () => 'Bearer ${sharedPref.getString(TOKEN)}');
    }
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: header,
        body: jsonEncode({"driver_id": driverId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return true;
      } else if (response.statusCode == 400) {
        appStore.setLoading(false);

        Fluttertoast.showToast(
          msg: "You have already in ride.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: const Color(0xFFF44336),
          textColor: const Color(0xFFFFFFFF),
        );
        return false;
      } else {
        appStore.setLoading(false);

        Fluttertoast.showToast(
          msg: "Something went wrong!.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: const Color(0xFFF44336),
          textColor: const Color(0xFFFFFFFF),
        );
        return false;
      }
    } catch (e) {
      appStore.setLoading(false);

      Fluttertoast.showToast(
        msg: "Something went wrong!.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: const Color(0xFFF44336),
        textColor: const Color(0xFFFFFFFF),
      );
      return false;
    }
  }
  Future<void> updateDriverId(BuildContext context,String rideId, int myDriverId) async {
    try {
      DocumentReference rideRef =
      FirebaseFirestore.instance.collection('rides').doc('ride_$rideId');
      final FirebaseFirestore fireStore = FirebaseFirestore.instance;
      late final CollectionReference rideRef2;
      rideRef2 = fireStore.collection('rides');
      QuerySnapshot rideSnapshot = await rideRef2.where('driver_ids', arrayContains: myDriverId).get();

      if (rideSnapshot.docs.isNotEmpty) {
        Fluttertoast.showToast(
          msg: "You already have an active ride!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 2,
        );
        return;
      }
      await rideRef.update({
        'driver_ids': FieldValue.arrayUnion([myDriverId]),
      });
      launchScreen(context, DashboardScreen());
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Something went wrong!.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: const Color(0xFFF44336),
        textColor: const Color(0xFFFFFFFF),
      );
    }
  }
  Future<void> scheduleupdateDriverId(BuildContext context, String rideId, int myDriverId, int riderid, String payment_type) async {

    try {
      DocumentReference rideRef = FirebaseFirestore.instance.collection('rides').doc('ride_$rideId');

      final FirebaseFirestore fireStore = FirebaseFirestore.instance;
      late final CollectionReference rideRef2;
      rideRef2 = fireStore.collection('rides');
      QuerySnapshot rideSnapshot = await rideRef2.where('driver_ids', arrayContains: myDriverId).get();

      if (rideSnapshot.docs.isNotEmpty) {
        appStore.setLoading(false);

        Fluttertoast.showToast(
          msg: "You already have an active ride!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 2,
        );
        return;
      }
      Map<String, dynamic> newRideData = {
        'driver_ids': FieldValue.arrayUnion([myDriverId]), // Add the new driver to the array
        'on_rider_stream_api_call': 0,
        'on_stream_api_call': 0,
        'status': NEW_RIDE_REQUESTED, // Ensure status is set properly
        'ride_id': int.tryParse(rideId),
        'rider_id': riderid,
        'payment_status': "",
        'payment_type': payment_type,
        'ride_has_bid': 0,
        'tips': 0,
      };
      widget.status==SCHEDULED? null: await rideRef.set(newRideData, SetOptions(merge: true));
      widget.status==SCHEDULED?await rideRequest(id: int.tryParse(rideId), status: SCHEDULED): await rideRequest(id: int.tryParse(rideId), status: NEW_RIDE_REQUESTED);
      widget.status==SCHEDULED?launchScreen(context, DashboardScreen(index: 1,)):launchScreen(context, DashboardScreen());
    } catch (e) {
      appStore.setLoading(false);
      Fluttertoast.showToast(
        msg: "Something went wrong!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: const Color(0xFFF44336),
        textColor: const Color(0xFFFFFFFF),
      );
    }
  }

  Future<void> rideRequest({String? status,int? id}) async {
    appStore.setLoading(true);
    Map req = {
      "id": id,
      "status": status,
      "driver_id":sharedPref.getInt(USER_ID)
    };
    await rideRequestUpdate(request: req, rideId: id)
        .then((value) async {
      appStore.setLoading(false);
    }).catchError((error) {
      print("xknlndl${error}");
      toast(error);
      appStore.setLoading(false);
      log(error.toString());
    });
  }


  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      return Stack(
        children: [
          AnimationLimiter(
            child: ListView.builder(
                itemCount: riderData.length,
                controller: scrollController,
                padding:
                    EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
                itemBuilder: (_, index) {
                  RiderModel data = riderData[index];
                  return AnimationConfiguration.staggeredList(
                    delay: Duration(milliseconds: 200),
                    position: index,
                    duration: Duration(milliseconds: 375),
                    child: SlideAnimation(
                      child: IntrinsicHeight(child: rideCardWidget(data: data)),
                    ),
                  );
                }),
          ),
          Visibility(
            visible: appStore.isLoading,
            child: loaderWidget(),
          ),
          if (riderData.isEmpty)
            appStore.isLoading ? SizedBox() : emptyWidget(),
        ],
      );
    });
  }

  Widget rideCardWidget({required RiderModel data}) {
    return inkWellWidget(
      onTap: () {
        if (data.status != CANCELED) {
          data.status ==NEW_RIDE_REQUESTED || data.status ==SCHEDULED?null:
          launchScreen(context, RideDetailScreen(orderId: data.id!),
              pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        margin: EdgeInsets.only(top: 8, bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: dividerColor),
          borderRadius: BorderRadius.circular(defaultRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Ionicons.calendar,
                        color: textSecondaryColorGlobal, size: 16),
                    SizedBox(width: 4),
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text('${printDate(data.createdAt.validate())}',
                          style: primaryTextStyle(size: 14)),
                    ),
                  ],
                ),
                Text('${language.rideId} #${data.id}',
                    style: boldTextStyle(size: 14)),
              ],
            ),
            Divider(height: 20, thickness: 0.5),
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.near_me, color: Colors.green, size: 18),
                      SizedBox(width: 4),
                      Expanded(
                          child: Text(data.startAddress.validate(),
                              style: primaryTextStyle(size: 14), maxLines: 2)),
                    ],
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      SizedBox(width: 8),
                      SizedBox(
                        height: 34,
                        child: DottedLine(
                          direction: Axis.vertical,
                          lineLength: double.infinity,
                          lineThickness: 1,
                          dashLength: 2,
                          dashColor: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.red, size: 18),
                      SizedBox(width: 4),
                      Expanded(
                          child: Text(data.endAddress.validate(),
                              style: primaryTextStyle(size: 14), maxLines: 2)),
                      data.status ==NEW_RIDE_REQUESTED
                          ? GestureDetector(
                        onTap: () async {
                          appStore.setLoading(true);
                          int? driverId = sharedPref.getInt(USER_ID);
                            if (driverId == null) return;
                            bool statusSuccess =
                                await checkDriverStatus(driverId);
                            if (!statusSuccess) return;
                            updateDriverId(context,data.id.toString(),driverId);
                          appStore.setLoading(false);
                        },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 7),
                                decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  'View',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                          : data.status ==SCHEDULED
                          ? GestureDetector(
                        onTap: () async {
                          appStore.setLoading(true);
                          int? driverId = sharedPref.getInt(USER_ID);
                          if (driverId == null) return;
                          bool statusSuccess =
                          await checkDriverStatus(driverId);
                          if (!statusSuccess) return;
                          scheduleupdateDriverId(context,data.id.toString(),driverId,data.riderId!,data.paymentType!);
                          appStore.setLoading(false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 7),
                          decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            widget.status==UPCOMING?"Take":'Assign to me',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ):SizedBox()
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 15,),
            data.status ==SCHEDULED?Text("Scheduled At : ${printDate(data.datetime.validate())}",style: primaryTextStyle(size: 14,color: Colors.green),):SizedBox()
          ],
        ),
      ),
    );
  }
}

