require 'panteao'
engine = Panteao::Panteao.new(project: './project.jcm')
engine.connect
engine.loop