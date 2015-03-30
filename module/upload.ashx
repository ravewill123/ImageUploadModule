<%@ WebHandler Language="C#" Class="upload" %>

using System;
using System.Web;
using System.Drawing;
using System.Drawing.Imaging;

public class upload : IHttpHandler {
    private string relativePath = @"tmp/";
    
    
    public void ProcessRequest (HttpContext context) {
        string result;
        try {
            if(context.Request["type"] == "upload"){
                // 上傳暫存檔案
                result = uploadImg(context);
            } else if (context.Request["type"] == "clip") {
                // 裁切暫存檔案
                result = clipImg(context);
            }else{
                result = Newtonsoft.Json.JsonConvert.SerializeObject(new { code = 500, message = "參數錯誤" });
            }
        } catch (HttpException exp) {
            result = Newtonsoft.Json.JsonConvert.SerializeObject(new { code = 500, message = exp.Message.ToString() + "圖檔上傳請小於2MB" });
        }
        context.Response.ContentType = "application/json";
        context.Response.Write(result);
    }

    // 上傳暫存檔案
    private string uploadImg(HttpContext context) {
        string absolutePath = context.Server.MapPath("~/" + relativePath);
        dynamic result;

        if (context.Request.Files.Count == 0) {
            result = new {
                code = 500,
                message = "無檔案上傳"
            };
        } else {

            HttpPostedFile aFile = context.Request.Files[0];
            if (aFile.ContentLength == 0 || String.IsNullOrEmpty(aFile.FileName)) {
                result = new {
                    code = 500,
                    message = "無檔案上傳"
                };
            }else if(aFile.ContentLength > 1024*1000*2){
                result = new {
                    code = 500,
                    message = "圖檔上傳請小於2MB"
                };
            } else {
                string displayFileName = System.IO.Path.GetFileName(aFile.FileName);
                string newName = DateTime.Now.ToString("yyyyMMddHHmmss") + CreateRandomCode(3);
                switch (aFile.ContentType) {
                    case "image/jpeg":
                    case "image/pjpeg":
                        newName += ".jpg";
                        break;
                    case "image/png":
                    case "image/x-png":
                        newName += ".png";
                        break;
                    case "image/gif":
                        newName += ".gif";
                        break;
                    default:
                        newName = "";
                        break;
                }
                if (newName != "") {
                    aFile.SaveAs(absolutePath + newName);
                    result = new {
                        code = 200,
                        pic = relativePath + newName
                    };
                } else {
                    result = new {
                        code = 500,
                        message = "非圖片類型文件，請重傳"
                    };
                }
            }
        }

        return Newtonsoft.Json.JsonConvert.SerializeObject(result);
    } 
    
    // 裁切暫存檔案
    private string clipImg(HttpContext context) {
        string absolutePath = context.Server.MapPath("~/" + relativePath);
        dynamic result;
        if (context.Request["cutW"] != null && context.Request["cutH"] != null && context.Request["x1"] != null && context.Request["y1"] != null && context.Request["w"] != null && context.Request["h"] != null && context.Request["pic"] != null) {
            try {
                string path = absolutePath + context.Request["pic"].Replace(relativePath, string.Empty);
                Image sourceImage = Image.FromFile(path);
                Image cropImage = this.CropImage(
                    sourceImage,
                    new Rectangle(Convert.ToInt32(context.Request["x1"]), Convert.ToInt32(context.Request["y1"]), Convert.ToInt32(context.Request["w"]), Convert.ToInt32(context.Request["h"]))
                );
                sourceImage.Dispose();
                Bitmap resizeImage = this.ResizeImage(cropImage, new Size(Convert.ToInt32(context.Request["cutW"]), Convert.ToInt32(context.Request["cutH"])));
                string pic = context.Request["pic"].Replace(relativePath, string.Empty);
                pic = pic.Replace(".jpg", string.Empty);
                pic = pic.Replace(".png", string.Empty);
                pic = pic.Replace(".gif", string.Empty);
                string filePath = String.Concat(pic, "_clip.jpg");
                SaveJpeg(absolutePath + filePath, resizeImage, 90L);
                System.IO.File.Delete(path); // 刪除舊上傳檔
                result = new {
                    code = 200,
                    pic = relativePath + filePath
                };
            } catch (Exception e) {
                result = new {
                    code = 500,
                    message = "裁切儲存異常"
                };
            }
        } else {
            result = new {
                code = 500,
                message = "缺少裁切資訊"
            };
        }

        return Newtonsoft.Json.JsonConvert.SerializeObject(result);
    }

    
    
    
    
    
    // 裁圖
    private System.Drawing.Image CropImage(System.Drawing.Image img, Rectangle cropArea) {
        Bitmap bmpImage = new Bitmap(img);
        Bitmap bmpCrop = bmpImage.Clone(cropArea, bmpImage.PixelFormat);
        return bmpCrop as System.Drawing.Image;
    }

    // 等比例縮圖
    private Bitmap ResizeImage(System.Drawing.Image imgToResize, Size size) {
        /*
        // 等比縮放 
        int sourceWidth = imgToResize.Width;
        int sourceHeight = imgToResize.Height;

        float nPercent = 0;
        float nPercentW = 0;
        float nPercentH = 0;

        nPercentW = ((float)size.Width / (float)sourceWidth);
        nPercentH = ((float)size.Height / (float)sourceHeight);

        if (nPercentH < nPercentW) {
            nPercent = nPercentH;
        } else {
            nPercent = nPercentW;
        }

        int destWidth = (int)(sourceWidth * nPercent);
        int destHeight = (int)(sourceHeight * nPercent);

        Bitmap bmp = new Bitmap(destWidth, destHeight);
        Graphics g = Graphics.FromImage((System.Drawing.Image)bmp);
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;

        g.DrawImage(imgToResize, 0, 0, destWidth, destHeight);
        g.Dispose();
        */
        // 強制變形縮成預定尺寸
        Bitmap bmp = new Bitmap(size.Width, size.Height);
        Graphics g = Graphics.FromImage((System.Drawing.Image)bmp);
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.Clear(Color.White);
        g.DrawImage(imgToResize, 0, 0, size.Width, size.Height);
        g.Dispose();
        return bmp;
    }

    // 存JPG
    private void SaveJpeg(string path, Bitmap img, long quality) {
        // Encoder parameter for image quality
        EncoderParameter qualityParam = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, quality);

        // Jpeg image codec
        ImageCodecInfo jpegCodec = this.getEncoderInfo("image/jpeg");

        if (jpegCodec == null) {
            return;
        }

        EncoderParameters encoderParams = new EncoderParameters(1);
        encoderParams.Param[0] = qualityParam;

        img.Save(path, jpegCodec, encoderParams);
        img.Dispose();
    }

    private ImageCodecInfo getEncoderInfo(string mimeType) {
        // Get image codecs for all image formats
        ImageCodecInfo[] codecs = ImageCodecInfo.GetImageEncoders();

        // Find the correct image codec
        for (int i = 0; i < codecs.Length; i++) {
            if (codecs[i].MimeType == mimeType) {
                return codecs[i];
            }
        }
        return null;
    }
        
    // 取亂數字串
    private string CreateRandomCode(int Number) {
        string allChar = "0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z";
        string[] allCharArray = allChar.Split(',');
        string randomCode = "";
        int temp = -1;

        Random rand = new Random();
        for (int i = 0; i < Number; i++) {
            if (temp != -1) {
                rand = new Random(i * temp * ((int)DateTime.Now.Ticks));
            }
            int t = rand.Next(36);
            if (temp != -1 && temp == t) {
                return CreateRandomCode(Number);
            }
            temp = t;
            randomCode += allCharArray[t];
        }
        return randomCode;
    }
    
    public bool IsReusable {
        get {
            return false;
        }
    }

}