_ = require 'underscore-plus'
{$$, View} = require 'atom'

ErrorView = require './error-view'
PackageManager = require './package-manager'
AvailablePackageView = require './available-package-view'

module.exports =
class PackagesPanel extends View
  @content: ->
    @div =>
      @div class: 'section packages', =>
        @div class: 'section-heading theme-heading icon icon-cloud-download', 'Install Packages'
        @div outlet: 'loadingMessage', class: 'padded text icon icon-hourglass', 'Loading packages\u2026'
        @div outlet: 'emptyMessage', class: 'padded text icon icon-heart', 'You have every package installed already!'
        @div outlet: 'errors'
        @div outlet: 'packageContainer', class: 'container package-container', ->

  initialize: (@packageManager) ->
    @subscribe @packageManager, 'package-install-failed', (pack, error) =>
      @errors.append(new ErrorView(error))

    @loadAvailablePackages()

  # Load and display the packages that are available to install.
  loadAvailablePackages: ->
    @loadingMessage.show()
    @emptyMessage.hide()

    @packageManager.getAvailable()
      .then (packages) =>
        installedPackages = atom.packages.getAvailablePackageNames()
        packages = packages.filter ({name, theme}) ->
          not theme and not (name in installedPackages)

        @loadingMessage.hide()
        if packages.length > 0
          for pack,index in packages
            if index % 4 is 0
              packageRow = $$ -> @div class: 'row'
              @packageContainer.append(packageRow)
            packageRow.append(new AvailablePackageView(pack, @packageManager))
        else
          @emptyMessage.show()
      .catch (error) =>
        @loadingMessage.hide()
        @errors.append(new ErrorView(error))