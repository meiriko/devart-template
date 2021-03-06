<html>
	<head>
		<link href="./styles/image.css" rel="stylesheet" type="text/css">
		<link href="./styles/colpick.css" rel="stylesheet" type="text/css"/>
		<script type="text/javascript" src="app/js/paper-full.js"></script>
		<script type="text/javascript" src="app/js/jquery.min.js"></script>
		<script type="text/javascript" src="app/js/utils.js"></script>
		<script type="text/javascript" src="app/js/urlUtils.js"></script>
		<script type="text/javascript" src="app/js/stringUtils.js"></script>
		<script type="text/javascript" src="app/js/colpick.js"></script>

		<script type="text/javascript">
			// Only executed our code once the DOM is ready.
			var mainPathGroup;
			var mainGroup;
			var rasters = [];
			var points;
			var relatedSegments;
			var imgData;
			var loadedImages = [];
			var imageMargin = 50;
			var maxSx = 0;
			var keysNum = 0;
			var animationSpeed = 1;
			var animationSleep = 0;
			var doAnimation = false;
			var animationDirection = 1;
			var animationMix = 0;

			var controlTemplate = '\
				<div class="control-box">\
					<div>\
						<div class="color-box" itemIndex="$index"></div>\
						<div class="range-label">$imageName\
							<input type="checkbox" checked="true" onchange="rasters[$index].visible=this.checked;loadedImages[$index].mainGroup.visible=this.checked;"/>\
						</div>\
					</div>\
					<div class="range-box">\
						<input type="range" min="0.0" max="1" value="$rasterOpacity" step="0.02" onchange="changeOpacity(rasters[$index], this.value)"></input>\
						<div class="range-label">image opacity</div>\
					</div>\
					<div class="range-box">\
						<input type="range" min="0.0" max="1" value="$drawingOpacity" step="0.02" onchange="changeOpacity(loadedImages[$index].mainGroup, this.value)"></input>\
						<div class="range-label">drawing opacity</div>\
					</div>\
					<div class="range-box">\
						<input id="mix$index" type="range" min="0.0" max="1" value="0" step="0.02" onchange="changeMix(loadedImages[$index], this.value)"></input>\
						<div class="range-label">mix</div>\
					</div>\
					<div class="range-box" $displayAnimation>\
						<div class="range-label">animate\
							<input type="checkbox" onchange="animate($index, this.checked);"/>\
						</div>\
						<input id="animationSpeed$index" type="range" min="0.5" max="5" value="1" step="0.2" onchange="animationSpeed = this.value"></input>\
						<div class="range-label">animation speed</div>\
					</div>\
				</div>\
			';

			window.onload = function() {
				params = getUrlParameters();
				if(params.hasOwnProperty('keys')){
					var keys = decodeURIComponent(params.keys).split(',');
					keysNum = keys.length;
					keys.forEach(function(key){
						loadByKey(key);
					});
				}
				// Get a reference to the canvas object
				var canvas = document.getElementById('canvas');
				// Create an empty project and a view for the canvas:
				paper.setup(canvas);
				paper.view.onFrame = animationTick;
				// Create a Paper.js Path to draw a line into it:
				// points = JSON.parse({{.Points}});

				mainPathGroup = new paper.Group();
				mainGroup = new paper.Group();
			}

			function rasterLoaded(){
				this.opacity = 0.5;
				this.moveBelow(mainPathGroup);
				this.moveBelow(mainGroup);
				
				if( rasters.length == keysNum ) {
					unifyScale(true);
				}
			}

			function unifyScale(rastersOnly) {
				for( var i = 0 ; i < loadedImages.length ; i++ ) {
					var rescaleX = maxSx / loadedImages[i].SX ;
					if( rastersOnly ){
						var scale = 1;
						if( rasters[i].width > 700 ) {
							scale = 700 / rasters[i].width ;
						}
						if( rasters[i].height > 500 ) {
							scale = Math.min(scale, 500 / rasters[i].height);
						}
						var relevantImageData = loadedImages[i];
						rasters[i].scale(rescaleX * scale, new paper.Point(0,0));
						rasters[i].position = new paper.Point(imageMargin + rescaleX*(scale * rasters[i].width/2 - relevantImageData.DX) , imageMargin + rescaleX * (scale * rasters[i].height/2 - relevantImageData.DY ) ) ;
					} else {
						loadedImages[i].SX *= rescaleX;
						loadedImages[i].SY *= rescaleX;
					}
				}
			}

			function loadByKey(key){
				$.getJSON('/imageData', {key: key}, function(image){
					maxSx = Math.max( maxSx, image.SX );
					loadedImages.push(image);
					var jsonPoints =  JSON.parse(image.Points);
					image.basePoints = jsonPoints.map( function(point){
						return new paper.Point( imageMargin + point[0] * image.SX , imageMargin + point[1] * image.SY );
					});
					var raster = new paper.Raster(image.ImageUrl);
					image.raster = raster;
					rasters.push(raster);
					raster.onLoad = rasterLoaded;
				});
			}

			function rect(x,y,w,h,config){
				config = config || {"strokeColor":"red"};
				if(! config.hasOwnProperty("strokeColor")){
					config.strokeColor = "red";
				}
				var val = new paper.Path.Rectangle( imageMargin + x * imgData.SX, imageMargin + y * imgData.SY,w * imgData.SX, h * imgData.SY);
				val.strokeColor = config.strokeColor;
				return val;
			}

			function path(pointsInd, config){
				config = config || {"strokeColor":"red"};
				var i;
				if(! config.hasOwnProperty("strokeColor")){
					config.strokeColor = "red";
				}
				var val = new paper.Path(config);
				val.moveTo( points[pointsInd[0]] );
				for( i = 1 ; i < pointsInd.length ; i++ ){
					val.lineTo( points[pointsInd[i]] );
				}
				for( i = 0 ; i < pointsInd.length ; i++ ){
					relatedSegments[pointsInd[i]].push( val.segments[i].point );
				}
				return val;
			}

			function xxpath(points, config){
				config = config || {"strokeColor":"red"};
				if(! config.hasOwnProperty("strokeColor")){
					config.strokeColor = "red";
				}
				var val = new paper.Path(config);
				val.moveTo( new paper.Point( imageMargin + points[0][0] * imgData.SX, imageMargin + points[0][1] * imgData.SY ) );
				for( var i = 1 ; i < points.length ; i++ ){
					val.lineTo( new paper.Point( imageMargin + points[i][0] * imgData.SX, imageMargin + points[i][1] * imgData.SY ) );
				}
				return val;
			}

			function drawShapesOnImages(config){
				unifyScale(false);
				var displayAnimation = (loadedImages.length === 1 ? "" : 'style="display:none"');
				loadedImages.forEach(function(image, index){
					if(! image.hasOwnProperty('mainGroup')){
						image.mainGroup = new paper.Group();
						image.mainGroup.opacity = 0.9;
						mainGroup.addChild(image.mainGroup);
						var controlString = stringTemplate(controlTemplate, {$imageName:loadedImages[index].Title, $index: index, $rasterOpacity: rasters[index].opacity, $drawingOpacity: image.mainGroup.opacity,$displayAnimation:displayAnimation});
						$('#controls').append( controlString );
						$('.color-box').colpick({
							colorScheme:'dark',
							layout:'rgbhex',
							color:'ffffff',
							onSubmit:function(hsb,hex,rgb,el) {
								var ind = parseInt($(el).attr('itemIndex'));
								loadedImages[ind].mainGroup.strokeColor = '#'+hex;
								$(el).css('background-color', '#'+hex);
								$(el).colpickHide();
							}
						}).css('background-color', '#ffffff');
					}

					/*
					var jsonPoints =  JSON.parse(image.Points);
					points = jsonPoints.map( function(point){
						return new paper.Point( point[0], point[1] );
					});
					*/
					points = image.basePoints;
					relatedSegments = image.relatedSegments;
					// console.log('points: ' , points.join(','));
					imgData = image;
					drawShapes(config, image.mainGroup, true);
				});

				paper.view.draw();
			}

			function drawShapes(config,group,clear){
				if( clear ){
					group.removeChildren();
				}
				Object.keys(config).forEach(function(key){
					if( key === 'name' ){
						console.log('drawing ' , config[key]);
					} else if( key === 'map' ){
						console.log('loading mapping');
					} else {
						var child = config[key];
						if(Array.isArray(child)){
							console.log('sub shapes!!!!');
							var shapes = child;
							var subGroup = new paper.Group();
							group.addChild(subGroup);
							shapes.forEach(function(shape){
								drawShapes( shape , subGroup, false);
							});
						} else {
							group.addChild(eval(config[key]));
						}
					}
				});
				if( clear ){
					// mainGroup.strokeColor = 'red';
					group.strokeWidth = 2;
					paper.view.draw();
				}
			}

			function changeOpacity(shape, val){
				if(Array.isArray(shape)){
					shape.forEach(function(item){
						item.opacity = val;
					});
				} else {
					shape.opacity = val;
				}
			}

			function updateImageMix(image, val){
				for( var i = 0 ; i < image.basePoints.length ; i++ ){
					var segmentPoints = image.relatedSegments[i];
					if(segmentPoints && segmentPoints.length){
						var newX = image.basePoints[i].x * (1 - val) + image.mappedPoints[i].x * val ;
						var newY = image.basePoints[i].y * (1 - val) + image.mappedPoints[i].y * val ;
						segmentPoints.forEach(function(point){
							point.x = newX;
							point.y = newY;
						});
					}
				}
				// image.relatedSegments[2][0].x = 100;
				// image.relatedSegments[4][0].y = 100;
				// paper.view.draw();
			}

			function animationTick(event){
				if( animationSleep > 0 ) {
					animationSleep-- ;
					return;
				}
				if( doAnimation ){
					animationMix += animationDirection * animationSpeed / 100;
					if( animationMix > 1 ) {
						animationDirection = -1 ;
						animationMix += animationDirection * animationSpeed / 100;
						animationSleep = 30 * animationSpeed;
					} else if( animationMix < 0 ) {
						animationDirection = 1 ;
						animationMix += animationDirection * animationSpeed / 100;
						animationSleep = 30 * animationSpeed;
					}
					document.getElementById("mix0").value = animationMix;
					changeMix(loadedImages[0] , animationMix);
				}
			}

			function animate(index, status){
				doAnimation = status;
				if( status ){
					animationMix = parseFloat( document.getElementById("mix0").value );
				}
			}

			function changeMix(shape, val){
				if(Array.isArray(shape)){
					shape.forEach(function(item){
						updateImageMix(item, val);
					});
				} else {
					updateImageMix(shape, val);
				}
			}

			function extractProperty(array, property){
				return array.map(function(item){
					return item[property];
					} );
			}

			function changeVisibility(array, visibility){
				array.forEach(function(item){
					item.visible = visibility;
				});
			}

			function xRange(ind1, ind2, ratio){
				return (mappedPoints[ind1].x * ratio + mappedPoints[ind2].x * (1-ratio));
				// return (p1[0] * ratio + p2[0] * (1-ratio));
			}

			function yRange(ind1, ind2, ratio){
				// return (p1[1] * ratio + p2[1] * (1-ratio));
				return (mappedPoints[ind1].y * ratio + mappedPoints[ind2].y * (1-ratio));
			}

			function mapPoints(mapConfig){
				loadedImages.forEach(function(image, index){
					image.mappedPoints = image.basePoints.map( function(point) {
						return (new paper.Point(point));
					});
					// array of arrays for later iteration
					image.relatedSegments = image.basePoints.map( function(point) {
						return [];
					});
					points = JSON.parse(image.Points);
					mappedPoints = image.mappedPoints;
					// points = image.Points;
					if(mapConfig.hasOwnProperty("keyPoints")){
						var kpConfig = mapConfig.keyPoints;
						Object.keys(kpConfig).forEach(function(key){
							var ind = parseInt(key);
							if( ! isNaN(ind) ){
								if( ind < image.mappedPoints.length ){
									var mappedValue = eval(kpConfig[key] );
									image.mappedPoints[ind] = new paper.Point( imageMargin + mappedValue[0] * image.SX , imageMargin + mappedValue[1] * image.SY );
								}
							}
						});
					}
					if(mapConfig.hasOwnProperty("points")){
						var pConfig = mapConfig.points;
						Object.keys(pConfig).forEach(function(key){
							var ind = parseInt(key);
							if( ! isNaN(ind) ){
								if( ind < image.mappedPoints.length ){
									var mapVal = eval(pConfig[key]);
									image.mappedPoints[ind].x = mapVal[0];
									image.mappedPoints[ind].y = mapVal[1];
								}
							}
						});
					}
				});
			}
		</script>
		<script>
			$.getJSON('configTitles', function(data) {
				var $select = $("#config");
				$select.on('change', function(){
					if( this.value && this.value.length ){
						$.getJSON('config',{key:this.value}, function(data){
							var config = JSON.parse(data.Config);
							if(config.hasOwnProperty("map")){
								mapPoints(config.map);
							}
							drawShapesOnImages(config, mainGroup);
						});
					}
				});
				$select.append($("<option>", { value: "", html: "select" }));
				Object.keys(data).forEach(function(key){
					$select.append($("<option>", { value: key, html: data[key] }));
				});
			}).fail(function(jqxhr, textStatus, error) {
				console.log( textStatus );
			});

		</script>
	</head>
	<body>
		<h2>Images comparison and morph</h2>
		<div>Select config: <select id="config" style="width: 200px;"></select></div>
		<div><canvas id="canvas" width="640" height="480" ></canvas></div>
		<div id="controls">
			<div class="control-box">
				<div class="range-label">all images
					<input type="checkbox" checked="true" onchange="changeVisibility(rasters,this.checked)"/>
				</div>
				<div class="range-label">all drawings
					<input type="checkbox" checked="true" onchange="changeVisibility(extractProperty(loadedImages,'mainGroup'),this.checked)"/>
				</div>
				<div class="range-box">
					<input type="range" min="0.0" max="1" value="$rasterOpacity" step="0.02" onchange="changeOpacity(rasters, this.value)"></input>
					<div class="range-label">image opacity</div>
				</div>
				<div class="range-box">
					<input type="range" min="0.0" max="1" value="$drawingOpacity" step="0.02" onchange="changeOpacity(extractProperty(loadedImages,'mainGroup'), this.value)"></input>
					<div class="range-label">drawing opacity</div>
				</div>
				<div class="range-box">
					<input type="range" min="0.0" max="1" value="0" step="0.02" onchange="changeMix(loadedImages, this.value)"></input>
					<div class="range-label">mix</div>
				</div>
			</div>
		</div>
	</body>
</html>
