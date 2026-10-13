sed -i '' '/analyzer:/a\
  language:\
    strict-casts: true\
    strict-inference: true\
    strict-raw-types: true\
' app/analysis_options.yaml
