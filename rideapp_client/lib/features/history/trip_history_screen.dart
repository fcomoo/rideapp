import 'package:flutter/material.dart';
import 'package:rideapp_client/features/rating/rating_widget.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TripHistoryScreen extends StatefulWidget {
  final String userId;
  const TripHistoryScreen({super.key, required this.userId});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _allTrips = [];
  String _filter = 'Todos';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _filter = ['Todos', 'Completados', 'Cancelados'][_tabController.index];
      });
    });
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    
    try {
      // Intentar fetch real
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/trips/history/${widget.userId}')
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        setState(() {
          _allTrips = jsonDecode(response.body);
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      print("Historial: Error API, usando mocks: $e");
    }

    // Datos Mock para Macuspana si falla la API o para demo
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _allTrips = _getMockData();
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _getMockData() {
    return [
      {
        "id": "1",
        "origin": "Palacio Municipal",
        "destination": "Hospital General",
        "price": 85.0,
        "status": "completed",
        "createdAt": "2024-03-20T10:30:00Z",
        "driverName": "Carlos Méndez",
        "rating": 5
      },
      {
        "id": "2",
        "origin": "Mercado Público",
        "destination": "Secundaria Técnica #1",
        "price": 45.0,
        "status": "completed",
        "createdAt": "2024-03-19T14:15:00Z",
        "driverName": "Juan Pérez",
        "rating": 4
      },
      {
        "id": "3",
        "origin": "Plaza Principal",
        "destination": "IMSS Macuspana",
        "price": 60.0,
        "status": "cancelled",
        "createdAt": "2024-03-18T09:00:00Z",
        "driverName": "Pedro Ruiz",
        "rating": null
      },
      {
        "id": "4",
        "origin": "Mis Blancos",
        "destination": "Terminal de Autobuses",
        "price": 120.0,
        "status": "completed",
        "createdAt": "2024-03-17T18:45:00Z",
        "driverName": "Carlos Méndez",
        "rating": 5
      },
      {
        "id": "5",
        "origin": "Colonia Centro",
        "destination": "Deportiva",
        "price": 50.0,
        "status": "completed",
        "createdAt": "2024-03-16T11:20:00Z",
        "driverName": "Roberto Díaz",
        "rating": 3
      },
      {
        "id": "6",
        "origin": "Chedraui",
        "destination": "Calle Gardenia",
        "price": 40.0,
        "status": "cancelled",
        "createdAt": "2024-03-15T20:10:00Z",
        "driverName": "Sofía Lara",
        "rating": null
      },
      {
        "id": "7",
        "origin": "ENTRADA",
        "destination": "Fracc. Siglo XXI",
        "price": 90.0,
        "status": "completed",
        "createdAt": "2024-03-14T07:30:00Z",
        "driverName": "Miguel Ángel",
        "rating": 5
      },
      {
        "id": "8",
        "origin": "Parque de Macuspana",
        "destination": "Colonia Belén",
        "price": 75.0,
        "status": "completed",
        "createdAt": "2024-03-13T16:50:00Z",
        "driverName": "Carlos Méndez",
        "rating": 5
      },
    ];
  }

  List<dynamic> get _filteredTrips {
    if (_filter == 'Completados') {
      return _allTrips.where((t) => t['status'] == 'completed').toList();
    } else if (_filter == 'Cancelados') {
      return _allTrips.where((t) => t['status'] == 'cancelled').toList();
    }
    return _allTrips;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Mis Viajes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1C1C1C),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B00),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFF6B00),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "Todos"),
            Tab(text: "Completados"),
            Tab(text: "Cancelados"),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHistory,
        color: const Color(0xFFFF6B00),
        backgroundColor: const Color(0xFF1C1C1C),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : _filteredTrips.isEmpty 
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                itemCount: _filteredTrips.length,
                itemBuilder: (context, index) => _buildTripCard(_filteredTrips[index]),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_car_filled_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 24),
              const Text(
                "Aún no has tomado ningún viaje",
                style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("Solicitar tu primer viaje", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    bool isCompleted = trip['status'] == 'completed';
    String dateStr = trip['createdAt'].split('T')[0];
    
    return Card(
      color: const Color(0xFF1C1C1C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.05))),
      margin: const EdgeInsets.only(bottom: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: isCompleted ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  "${trip['origin']} → ${trip['destination']}",
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "\$${trip['price']}",
                style: TextStyle(
                  color: isCompleted ? const Color(0xFFFF6B00) : Colors.white24,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.white.withOpacity(0.4)),
                const SizedBox(width: 6),
                Text(dateStr, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                const SizedBox(width: 12),
                Icon(Icons.person, size: 12, color: Colors.white.withOpacity(0.4)),
                const SizedBox(width: 6),
                Text(trip['driverName'], style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ],
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCompleted)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        "Precio estimado • Cancelado",
                        style: TextStyle(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  if (isCompleted && trip['rating'] != null)
                    Row(
                      children: [
                        const Text("Tu calificación:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 8),
                        RatingWidget(rating: double.parse(trip['rating'].toString()), size: 14),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    "ID de Viaje: ${trip['id']}",
                    style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
