path = require 'path'

_ = require 'underscore-plus'
fs = require 'fs-plus'
{$, $$, TextEditorView, View} = require 'atom-space-pen-views'
{Subscriber} = require 'emissary'

PackageCard = require './package-card'
Client = require './atom-io-client'
ErrorView = require './error-view'
PackageManager = require './package-manager'

module.exports =
class InstallPanel extends View
  Subscriber.includeInto(this)

  @content: ->
    @div =>
      @div class: 'section packages', =>
        @div class: 'section-container', =>
          @h1 outlet: 'installHeading', class: 'section-heading icon icon-cloud-download', 'Install Packages'

          @div class: 'text native-key-bindings', tabindex: -1, =>
            @span class: 'icon icon-question'
            @span outlet: 'publishedToText', 'Packages are published to '
            @a class: 'link', outlet: "openAtomIo", "atom.io"
            @span " and are installed to #{path.join(process.env.ATOM_HOME, 'packages')}"

          @div class: 'search-container clearfix', =>
            @div class: 'editor-container', =>
              @subview 'searchEditorView', new TextEditorView(mini: true)
            @div class: 'btn-group', =>
              @button outlet: 'searchPackagesButton', class: 'btn btn-default selected', 'Packages'
              @button outlet: 'searchThemesButton', class: 'btn btn-default', 'Themes'

          @div outlet: 'searchErrors'
          @div outlet: 'searchMessage', class: 'alert alert-info search-message icon icon-search'
          @div outlet: 'resultsContainer', class: 'container package-container'

      @div class: 'section packages', =>
        @div class: 'section-container', =>
          @div outlet: 'featuredHeading', class: 'section-heading icon icon-star'
          @div outlet: 'featuredErrors'
          @div outlet: 'loadingMessage', class: 'alert alert-info featured-message icon icon-hourglass'
          @div outlet: 'featuredContainer', class: 'container package-container'

  initialize: (@packageManager) ->
    client = $('.settings-view').view()?.client
    @client = @packageManager.getClient()
    @atomIoURL = 'https://atom.io/packages'
    @openAtomIo.on 'click', =>
      require('shell').openExternal(@atomIoURL)
      false

    @searchMessage.hide()

    @searchEditorView.getModel().setPlaceholderText('Search packages')
    @searchType = 'packages'
    @handleSearchEvents()

    @loadFeaturedPackages()

  detached: ->
    @unsubscribe()

  focus: ->
    @searchEditorView.focus()

  handleSearchEvents: ->
    @subscribe @packageManager, 'package-install-failed', (pack, error) =>
      @searchErrors.append(new ErrorView(@packageManager, error))

    @subscribe atom.commands.add @searchEditorView.element, 'core:confirm', =>
      @performSearch()

    @searchPackagesButton.on 'click', =>
      unless @searchPackagesButton.hasClass('selected')
        @searchType = 'packages'
        @searchPackagesButton.addClass('selected')
        @searchThemesButton.removeClass('selected')
        @searchEditorView.getModel().setPlaceholderText('Search packages')
        @publishedToText.text('Packages are published to ')
        @atomIoURL = 'https://atom.io/packages'
        @loadFeaturedPackages()
        @performSearch()

    @searchThemesButton.on 'click', =>
      unless @searchThemesButton.hasClass('selected')
        @searchType = 'themes'
        @searchThemesButton.addClass('selected')
        @searchPackagesButton.removeClass('selected')
        @searchEditorView.getModel().setPlaceholderText('Search themes')
        @publishedToText.text('Themes are published to ')
        @atomIoURL = 'https://atom.io/themes'
        @loadFeaturedPackages(true)
        @performSearch()

  performSearch: ->
    if query = @searchEditorView.getText().trim()
      @search(query)

  search: (query) ->
    @resultsContainer.empty()
    @searchMessage.text("Searching #{@searchType} for \u201C#{query}\u201D\u2026").show()

    opts = {}
    opts[@searchType] = true
    @packageManager.search(query, opts)
      .then (packages=[]) =>
        if packages.length is 0
          @searchMessage.text("No #{@searchType.replace(/s$/, '')} results for \u201C#{query}\u201D").show()
        else
          @searchMessage.hide()
        @addPackageViews(@resultsContainer, packages)
      .catch (error) =>
        @searchMessage.hide()
        @searchErrors.append(new ErrorView(@packageManager, error))

  addPackageViews: (container, packages) ->
    container.empty()

    for pack, index in packages
      packageRow = $$ -> @div class: 'row'
      container.append(packageRow)
      packageRow.append(new PackageCard(pack, @packageManager, back: 'Install'))

  filterPackages: (packages, themes) ->
    packages.filter ({theme}) ->
      if themes
        theme
      else
        not theme

  # Load and display the featured packages that are available to install.
  loadFeaturedPackages: (loadThemes) ->
    loadThemes ?= false
    @featuredContainer.empty()

    if loadThemes
      @installHeading.text 'Install Themes'
      @featuredHeading.text 'Featured Themes'
      @loadingMessage.text('Loading featured themes\u2026')
    else
      @installHeading.text 'Install Packages'
      @featuredHeading.text 'Featured Packages'
      @loadingMessage.text('Loading featured packages\u2026')

    @loadingMessage.show()

    handle = (error) =>
      @loadingMessage.hide()
      @featuredErrors.append(new ErrorView(@packageManager, error))

    if loadThemes
      @client.featuredThemes (error, themes) =>
        if error
          handle(error)
        else
          @loadingMessage.hide()
          @featuredHeading.text 'Featured Themes'
          @addPackageViews(@featuredContainer, themes)

    else
      @client.featuredPackages (error, packages) =>
        if error
          handle(error)
        else
          @loadingMessage.hide()
          @featuredHeading.text 'Featured Packages'
          @addPackageViews(@featuredContainer, packages)
