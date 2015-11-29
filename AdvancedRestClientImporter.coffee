parseQuery = (qstr) ->
  # from http://stackoverflow.com/a/13419367/1698645
  query = {}
  components = qstr.substr(1).split('&')
  for component in components
    keyValue = component.split('=')
    query[decodeURIComponent(keyValue[0])] = decodeURIComponent(keyValue[1] || '')
  return query

AdvancedRestClientImporter = ->

    # Create a Paw request from a Advanced Rest Client request (object)
    @importRequest = (context, inputRequest) ->

        # Create Paw request
        pawRequest = context.createRequest inputRequest.name, inputRequest.method, inputRequest.url

        # Add Headers
        # Advanced Rest Client stores headers like HTTP headers, separated by \n
        contentType = null
        if inputRequest.headers
          inputHeaders = inputRequest.headers.split "\n"
          for headerLine in inputHeaders
              match = headerLine.match /^([^\s\:]*)\s*\:\s*(.*)$/
              if match
                  pawRequest.setHeader match[1], match[2]
                  if match[1].toLowerCase() == 'content-type'
                    contentType = match[2].split(';')[0].trim()

        # Set Form URL-Encoded body
        if contentType == "application/x-www-form-urlencoded"
            keyValues = parseQuery (inputRequest.payload || '')
            pawRequest.urlEncodedBody = keyValues

        # Set Multipart body
        else if contentType == "multipart/form-data"
            keyValues = parseQuery (inputRequest.payload || '')
            pawRequest.multipartBody = keyValues

        # Set raw or JSON body
        else if inputRequest.payload and inputRequest.payload.length > 0
            foundBody = false

            # If the Content-Type contains "json" make it a JSON body
            if contentType and contentType.indexOf("json") >= 0
                jsonObject = null
                # try to parse JSON body input
                try
                    jsonObject = JSON.parse inputRequest.payload
                catch error
                    console.error "Cannot parse request JSON, will set as plain text"
                # set the JSON body
                if jsonObject
                    pawRequest.jsonBody = jsonObject
                    foundBody = true

            if not foundBody
                pawRequest.body = inputRequest.payload

        return pawRequest

    @importAllRequests = (context, inputTree) ->
      if not inputTree.requests
        throw new Error "Input Advanced Rest Client file doesn't have any request to import"

      # build project map
      projectMap = @buildProjectMap inputTree
      pawProjectMap = {}

      for inputRequest in inputTree.requests
        # create request
        pawRequest = @importRequest context, inputRequest

        # get group
        pawGroup = @getPawGroup context, projectMap, pawProjectMap, inputRequest.project

        # add request to group
        pawGroup.appendChild pawRequest
        
    @buildProjectMap = (inputTree) ->
      projectMap = {}
      if inputTree.projects
        for project in inputTree.projects
          projectMap[project.id] = project
      return projectMap

    @getPawGroup = (context, projectMap, pawProjectMap, projectId) ->
      if projectId and projectMap[projectId]
        pawProject = pawProjectMap[projectId]
        if not pawProject
          pawProject = context.createRequestGroup projectMap[projectId].name
          pawProjectMap[projectId] = pawProject
        return pawProject
      else
        pawProject = pawProjectMap[-1]
        if not pawProject
          pawProject = context.createRequestGroup 'Default (Advanced Rest Client)'
          pawProjectMap[-1] = pawProject
        return pawProject

    @importString = (context, string) ->

        # Parse JSON collection
        try
            inputTree = JSON.parse string
        catch error
            throw new Error "Invalid Advanced Rest Client file (not a valid JSON)"
        if not inputTree
            throw new Error "Invalid Advanced Rest Client file (missing root data)"

        @importAllRequests context, inputTree

        return true

    return

AdvancedRestClientImporter.identifier = "com.luckymarmot.PawExtensions.AdvancedRestClientImporter"
AdvancedRestClientImporter.title = "Advanced Rest Client Importer"

registerImporter AdvancedRestClientImporter
