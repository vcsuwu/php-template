{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = { self, nixpkgs, devenv, systems, ... } @ inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = forEachSystem (system: {
        devenv-up = self.devShells.${system}.default.config.procfileScript;
      });

      devShells = forEachSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
	        ({ pkgs, config, ... }:
                {
		  languages.php = {
		    enable = true;
		    fpm.pools.web.settings = {
		    "pm" = "dynamic";
		    "pm.max_children" = 5;
		    "pm.start_servers" = 2;
		    "pm.min_spare_servers" = 1;
		    "pm.max_spare_servers" = 5;
		    };
		  };
		  services.nginx = {
		    enable = true;
		    httpConfig = ''
		    server {
		      listen 8080;
		      root ${~/test-php};
		      index index.php index.html;
		      location / {
		        try_files $uri $uri/ =404;
		      }
		      location ~ \.php$ {
			fastcgi_index index.php;
		        fastcgi_pass unix:${config.languages.php.fpm.pools.web.socket};
			fastcgi_param   QUERY_STRING            $query_string;
			fastcgi_param   REQUEST_METHOD          $request_method;
			fastcgi_param   CONTENT_TYPE            $content_type;
			fastcgi_param   CONTENT_LENGTH          $content_length;

			fastcgi_param   SCRIPT_FILENAME         $document_root$fastcgi_script_name;
			fastcgi_param   SCRIPT_NAME             $fastcgi_script_name;
			fastcgi_param   PATH_INFO               $fastcgi_path_info;
			fastcgi_param   PATH_TRANSLATED         $document_root$fastcgi_path_info;
			fastcgi_param   REQUEST_URI             $request_uri;
			fastcgi_param   DOCUMENT_URI            $document_uri;
			fastcgi_param   DOCUMENT_ROOT           $document_root;
			fastcgi_param   SERVER_PROTOCOL         $server_protocol;

			fastcgi_param   GATEWAY_INTERFACE       CGI/1.1;
			fastcgi_param   SERVER_SOFTWARE         nginx/$nginx_version;

			fastcgi_param   REMOTE_ADDR             $remote_addr;
			fastcgi_param   REMOTE_PORT             $remote_port;
			fastcgi_param   SERVER_ADDR             $server_addr;
			fastcgi_param   SERVER_PORT             $server_port;
			fastcgi_param   SERVER_NAME             $server_name;

			fastcgi_param   HTTPS                   $https;

			fastcgi_param   REDIRECT_STATUS         200;
		      }

		    }
		    '';
		  };
                })
              ];
            };
          });
    };
}
