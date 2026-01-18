
module Telegem
  module Scene
    class Middleware
      def call(ctx, next_middleware)
        # Check if user is in a scene
        if ctx.session[:telegem_scene]
          scene_data = ctx.session[:telegem_scene]
          scene = ctx.bot.scenes[scene_data[:id].to_sym]
          
          if scene
            # Let scene handle it
            scene.process(ctx)
            return  # Don't call regular handlers
          end
        end
        
        # Not in scene, proceed normally
        next_middleware.call(ctx)
      end
    end
  end
end