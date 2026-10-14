package com.abonex.abonex

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (et non FlutterActivity) est OBLIGATOIRE
// pour local_auth : la boîte de dialogue biométrique Android est un
// Fragment, elle ne peut pas s'afficher sur une FlutterActivity simple.
class MainActivity : FlutterFragmentActivity()
