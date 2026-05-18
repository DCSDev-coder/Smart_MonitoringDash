import 'remember_me_store_base.dart';
import 'remember_me_store_mobile.dart'
    if (dart.library.html) 'remember_me_store_web.dart';

final RememberMeStore rememberMeStore = createRememberMeStore();

