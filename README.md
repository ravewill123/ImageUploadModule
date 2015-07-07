#ImageUploadModule

A simple image upload and croppers Module for PHP and C#.
You can crop images to custom size.

##Requirements
- php >= 5.3
- .NET Framework 4

##Usage
```

<script>
	function uploadCallback(pic, parameter){
		// pic => picturn name
		// parameter => iframe GET data "p"
	}
</script>

<iframe src="module/ImageUploadModule.html?w=320&h=240&p=%23p1&callback=uploadCallback" width="550" height="450"></iframe>

```