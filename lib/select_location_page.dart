import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';

// 与 android/app/src/main/AndroidManifest.xml 中配置的 Maps API Key 保持一致
const String _googleMapsApiKey = 'AIzaSyCbB8on2ZFtT9TFhCQSYhMqeu8x1I_Sr08';

class SelectLocationPage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const SelectLocationPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<SelectLocationPage> createState() => _SelectLocationPageState();
}

class _SelectLocationPageState extends State<SelectLocationPage> {
  static const LatLng _defaultCenter = LatLng(3.1390, 101.6869); // 吉隆坡

  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  late LatLng _centerLatLng;
  String _address = '正在定位...';
  bool _isResolvingAddress = false;

  @override
  void initState() {
    super.initState();
    _centerLatLng = (widget.initialLatitude != null && widget.initialLongitude != null)
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : _defaultCenter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _resolveAddressFromCenter() async {
    setState(() => _isResolvingAddress = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        _centerLatLng.latitude,
        _centerLatLng.longitude,
      );
      String address = '';
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        address = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
      }
      if (!mounted) return;
      setState(() {
        _address = address.isNotEmpty ? address : '未知地点';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _address = '无法识别该地点地址');
    } finally {
      if (mounted) setState(() => _isResolvingAddress = false);
    }
  }

  void _onCameraMove(CameraPosition position) {
    _centerLatLng = position.target;
  }

  void _onCameraIdle() {
    _resolveAddressFromCenter();
  }

  void _onPlaceSelected(Prediction prediction) {
    final lat = double.tryParse(prediction.lat ?? '');
    final lng = double.tryParse(prediction.lng ?? '');
    if (lat == null || lng == null) return;
    _centerLatLng = LatLng(lat, lng);
    _mapController?.animateCamera(CameraUpdate.newLatLng(_centerLatLng));
  }

  void _confirmLocation() {
    Navigator.pop(context, {
      'address': _address,
      'latitude': _centerLatLng.latitude,
      'longitude': _centerLatLng.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _centerLatLng,
                zoom: 16,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                _resolveAddressFromCenter();
              },
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),

          // 📍 固定在屏幕正中的橙色 marker（地图移动，marker 不动）
          const Positioned.fill(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_pin,
                  color: Color(0xFFFF5E00),
                  size: 48,
                ),
              ),
            ),
          ),

          // 🔎 顶部搜索框
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GooglePlaceAutoCompleteTextField(
                        textEditingController: _searchController,
                        googleAPIKey: _googleMapsApiKey,
                        inputDecoration: InputDecoration(
                          hintText: '搜索地址或地点',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        boxDecoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isLatLngRequired: true,
                        itemClick: (prediction) {
                          _searchController.text = prediction.description ?? '';
                        },
                        getPlaceDetailWithLatLng: _onPlaceSelected,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 📌 底部地址卡片 + 确认按钮
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFFF5E00)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _isResolvingAddress
                              ? const Text('正在解析地址...')
                              : Text(
                                  _address,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isResolvingAddress ? null : _confirmLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5E00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '确认此地点',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
