import 'dart:io';

class LocalProfilePhoto {
  static File? imageFile;

  static void setImage(File file) {
    imageFile = file;
  }
}
