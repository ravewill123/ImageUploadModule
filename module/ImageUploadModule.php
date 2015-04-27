<?php

/**
   * ImageUploadModule
   * @version 1.0
   * @require php >= 5.3
   * @author Technic <technic@webgene.com.tw>
   */
  

// Set Max File Size.
ini_set('upload_max_filesize', '2M');
define("UPLOAD_SIZE",2000000); //2M

// Status code: 500 Fail, 200 OK.
$code    = 500;
$message = "Internal Error";
$pic     = null;

$timestamp = date("YmdHis");

/**
  * 
  * Uploads a file
  *
  * @param string $pic  $_FILES['picfile'] or $_POST['pic'] Required.
  * @param string $type "UPLOAD" or "CLIP" , Default UPLOAD  Required.
  * @param integer $new_width  result W
  * @param integer $new_height  result H
  * @param string $x1  point LT x
  * @param string $y1  point LT y
  * @param string $x2  point RB x
  * @param string $y2  point RB y
  * @param string $directory  tmp,result path
  * @return string json_data { "code"=>$code,"message"=>$message,"pic"=>$pic }
*/

try {

  if(!isset($_POST['type'])) {
    throw new Exception("缺少功能類型參數");
  }

  $type = strtoupper($_POST['type']);
  $directory = (isset($_POST['directory']))?  $_POST['directory'] : "tmp/";

  switch ($type) {

    // Crop image by x,y
    case 'CLIP':
      
      if(!isset($_POST['pic'])) {
        throw new Exception("缺少圖檔路徑參數");
      }

      if(!isset($_POST['cutW']) || !isset($_POST['cutH'])) {
        throw new Exception("缺少尺寸參數");
      }

      if(!isset($_POST['x1']) || !isset($_POST['x2']) || !isset($_POST['y1']) || !isset($_POST['y2'])) {
        throw new Exception("缺少座標參數");
      }

      $img        = $directory . $_POST['pic'];
      $new_width  = $_POST['cutW'];
      $new_height = $_POST['cutH'];
      $x1         = $_POST['x1'];
      $x2         = $_POST['x2'];
      $y1         = $_POST['y1'];
      $y2         = $_POST['y2'];

      $finfo = new finfo(FILEINFO_MIME_TYPE);
      if (false === $ext = array_search($finfo->file($img),array('jpg' => 'image/jpeg','png' => 'image/png','gif' => 'image/gif'),true)) {
          throw new exception('圖片格式不符');
      }

      switch ($finfo->file($img)) {
        case 'image/jpeg':
          $img_type = 'jpg';
          $image_source = imagecreatefromjpeg($img);
          break;
        case 'image/png':
          $img_type = 'png';
          $image_source = imagecreatefrompng($img);
          break;
        case 'image/gif':
          $img_type = 'gif';
          $image_source = imagecreatefromgif($img);
          break;
      }

      // Crop info
      $img_info = getimagesize($img);
      $width    = $img_info['0'];
      $height   = $img_info['1'];
      
      $cropW = $x2 - $x1;
      $cropH = $y2 - $y1;

      // Create Crop Image 
      $crop = imagecreatetruecolor($cropW, $cropH);  


      if($img_type === "png"){
        $background = imagecolorallocate($image_source, 0, 0, 0);
        imagecolortransparent($image_source, $background);
        imagealphablending($image_source, false);
        imagesavealpha($image_source, true);
      }

      imagecopy(  
             $crop,   
             $image_source,   
             0,0,
             $x1,
             $y1,
             $cropW,   
             $cropH
      ); 

      $resize = imagecreatetruecolor($new_width , $new_height);  
        
      // Resize Image 
      imageCopyResampled(  
         $resize,   
         $crop,   
         0,   
         0,   
         0,   
         0,   
         $new_width,   
         $new_height,   
         $cropW,   
         $cropH  
      );

      $filename = explode(".",$_POST['pic']);


      if(!imagejpeg($resize, $directory . $filename[0].".jpg")){
        throw new Exception("合成圖片失敗");
      }

      $code    = 200;
      $message = null;
      $pic     = $directory . $filename[0].".jpg";   

      break;

    // Upload img and return tmp path.
    case 'UPLOAD':
    default:

      if(!isset($_FILES['picfile'])){
        throw new Exception("請上傳一張圖檔");
      }


      $file      = $_FILES['picfile'];

      if($file["size"] > UPLOAD_SIZE)
      {
        throw new exception("上傳的檔案⼤⼩超過了規定⼤⼩");
      }
      
      if ($file["error"] > 0)
      {
        throw new exception("圖檔有誤");
      }

      $finfo = new finfo(FILEINFO_MIME_TYPE);
      if (false === $ext = array_search($finfo->file($file['tmp_name']),array('jpg' => 'image/jpeg','png' => 'image/png','gif' => 'image/gif'),true)) {
          throw new exception('圖片格式不符');
      }

      switch ($finfo->file($file['tmp_name'])) {
        case 'image/jpeg':
          $ext = ".jpg";
          break;
        case 'image/png':
          $ext = ".png";
          break;
        case 'image/gif':
          $ext = ".gif";
          break;
      }


      $filename = md5(uniqid(rand()))."_".$timestamp.$ext;
      if(!move_uploaded_file($file["tmp_name"],iconv("utf-8", "big5", $directory . $filename)))
      {
        throw new exception("File moves failed"); 
      }

      $code    = 200;
      $pic     = $filename;
      $message = null;

      break;
  }
 
  
} catch (Exception $e) {
  $message = $e -> getMessage();  
} catch (FileException $e) {
  $message = $e -> getMessage();  
}


$resultArr = array("code"=>$code,"message"=>$message,"pic"=>$pic);
echo json_encode($resultArr);

?>