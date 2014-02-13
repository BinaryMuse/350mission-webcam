app = angular.module 'webcam', ['ngRoute']

app.config ($routeProvider) ->
  $routeProvider
    .when '/images',
      resolve:
        image: ($route, $location, album) ->
          album.images().then (imgs) ->
            $location.replace()
            $location.url "/images/#{imgs.length}"
    .when '/images/:id',
      controller: 'PicsController'
      templateUrl: 'pics.html'
      resolve:
        image: ($route, album) ->
          album.getImage $route.current.params.id
    .otherwise
      redirectTo: '/images'

app.directive 'wcKeys', ($document) ->
  scope:
    keys: '=wcKeys'
  link: (scope, elem, attrs) ->
    angular.element($document).bind 'keydown', (evt) ->
      if fn = scope.keys[evt.which]
        scope.$parent.$apply fn
    scope.$on '$destroy', ->
      angular.element($document).unbind 'keydown'

app.factory 'pics', ($http) ->
  ->
    $http.get('/records')

app.factory 'album', ($q, $rootScope, pics) ->
  _promise: null
  pinned: true

  images: ->
    @_promise || @refresh()

  getImage: (number) ->
    number = parseInt number, 10

    @images().then (imgs) ->
      deferred = $q.defer()
      if number < 1
        deferred.reject("No image #{number}")
      else if number > imgs.length
        deferred.reject("No image #{number}")
      else
        src = imgs[number - 1].url
        img = new Image()
        img.onload = ->
          $rootScope.$apply ->
            deferred.resolve(src)
        img.onerror = ->
          deferred.reject("Image load failed")
        img.src = src
      deferred.promise

  imageCount: ->
    @images().then (imgs) ->
      imgs.length

  refresh: ->
    deferred = $q.defer()
    @_promise = deferred.promise
    pics().success (data) ->
      deferred.resolve(data.records)
    deferred.promise

app.controller 'RoutingController', ($location, $scope, $window) ->
  $scope.loading = false
  $scope.anythingEverLoaded = false

  $scope.$on '$routeChangeStart', ->
    $scope.loading = true

  $scope.$on '$routeChangeSuccess', ->
    $scope.loading = false
    $scope.anythingEverLoaded = true

  $scope.$on '$routeChangeError', ->
    $scope.loading = false

    if !$scope.anythingEverLoaded
      $location.replace()
      $location.url '/images'

app.controller 'PicsController', ($scope, $interval, $window, $routeParams, $location, image, album) ->
  $scope.pinned = album.pinned
  $scope.image = image
  $scope.currentImageNumber = parseInt $routeParams.id, 10
  album.images().then (imgs) ->
    $scope.totalImages = imgs.length

  switchToImage = (number, removePinned = true) ->
    return if number <= 0 || number > $scope.totalImages
    $scope.pinned = album.pinned = false if removePinned
    $location.url "/images/#{number}"

  $scope.imagePrompt = ->
    number = $window.prompt 'Switch to which image?'
    number = parseInt number, 10
    unless isNaN number
      switchToImage number

  $scope.prevImage = ->
    switchToImage $scope.currentImageNumber - 1

  $scope.nextImage = ->
    switchToImage $scope.currentImageNumber + 1

  $scope.togglePinned = ->
    $scope.pinned = !$scope.pinned
    album.pinned = $scope.pinned
    if $scope.pinned
      switchToImage $scope.totalImages, false

  interval = $interval ->
    album.refresh().then (imgs) ->
      $scope.totalImages = imgs.length
      switchToImage $scope.totalImages, false if $scope.pinned
  , 2 * 60 * 1000

  $scope.$on '$destroy', -> $interval.cancel interval
