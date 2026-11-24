CREATE OR REPLACE FUNCTION IT.FUG_CLI_CONFIDENCIAL
 (P_COD_PERSONA IN varchar2
 )
 RETURN VARCHAR2
 IS
v_puede_ver        varchar2(1) := 'N';
  v_oficial          varchar2(1) := 'N';
  v_promotor         varchar2(1) := 'N';
  v_cod_oficial      ba_usuarios.cod_usuario%type;
  v_cod_promotor     ba_usuarios.cod_usuario%type;
  v_supervisor       ba_usuarios.cod_usuario%type;
  v_es_supervisor    varchar2(1) := 'N';
  v_confidencial     ge_clientes.cli_confidencial%type;
  v_cod_persona      ba_personas.cod_persona%type;
  v_cod_oficina      ge_clientes.cod_oficina%type;
  v_ver_cli_confidencial varchar2(01);
  v_cod_area   ba_usuarios.cod_area%type;
  v_cod_ofi_usuario  number;
  v_cat_usuario        ba_usuarios.categoria%type;
  v_cat_gestor         ba_usuarios.categoria%type;
  v_tipo               ba_personas.tipo%type;
begin
   --- Recupero datos del usuario
   Begin
      Select oficial, promotor, cod_persona, ver_cli_confidencial, cod_area,
             cod_oficina, categoria
        into v_oficial, v_promotor, v_cod_persona, v_ver_cli_confidencial,
             v_cod_area, v_cod_ofi_usuario, v_cat_usuario
        from ba_usuarios
       where cod_usuario = user;
   Exception
      When NO_DATA_FOUND Then
          Return ('N'); --- No es usuario el que consulta
   End;
   --- Si el que consulta es la propia persona mostrar
   if v_cod_persona = p_cod_persona or NVL(v_ver_cli_confidencial,'N') = 'S' then
      return ('S');
   end if;
   --- Recupero datos del cliente
   begin
      Select cod_usu_oficial, cod_usu_promotor, nvl(cli_confidencial,'N'),
             cod_oficina, p.tipo
        into v_cod_oficial, v_cod_promotor, v_confidencial,
             v_cod_oficina, v_tipo
        from ge_clientes c, ba_personas p
       where c.cod_persona(+) = p.cod_persona
         and p.cod_persona = p_cod_persona;
   exception
      When NO_DATA_FOUND Then
          Return ('N'); --- No existe el cliente o persona
   end;
   --Este control se realizará sólo para personas de tipo juridica por requerimiento del AP 2909
   if v_cat_usuario = 'CC' and v_tipo = 'J' then
       -- Lógica para usuarios Call Center.
       -- Si el usuario es categoría Call Center (CC) puede ver solo si
       -- la Categoría del gestor del cliente es "Gestor No Personalizado" (GP).
       begin
         select categoria
           into v_cat_gestor
           from ba_usuarios
          where cod_usuario = v_cod_oficial;
       exception
         when no_data_found then
           return ('N');
         when others then
           return ('N');
       end;
       if v_cat_gestor != 'GP' then
         return ('N');
       end if;
   end if;
   
   Begin
      -- El usuario es supervisor de algun promotor...
      Select distinct 'S'
        into v_es_supervisor
        from ba_usuarios
       where cod_usu_supervisor = user;
   Exception
      When NO_DATA_FOUND Then
         v_es_supervisor := 'N';
   End;
   
   if v_confidencial = 'N' THEN
      return 'S'; -- sino es confidencial se puede ver
   else
     
       -- veo si es confidencial y el usuario es operativo de la sucursal
       if v_cod_oficina = v_cod_ofi_usuario and
          v_cod_area = fug_obt_pardinamico('COD_AREA_OPERATIVA',null,null,null,v_cod_ofi_usuario) then
          return 'S'; 
       end if;
       -- Logica para usuarios promotores
       If ((v_promotor = 'S' and v_oficial = 'N') or v_es_supervisor = 'S' or
            v_oficial = 'S') Then
          -- Si el usuario es un oficial o promotor --- Verificar si el cliente es suyo
          -- El oficial puede ver todos los clientes, los promotores y los supervisores no deben poder ver...
          If nvl(v_cod_promotor, 'x') = nvl(user,'x') or
             nvl(v_cod_oficial, 'x') = nvl(user,'x')  Then
             return ('S');
          end if;
          if v_confidencial = 'N' then
             ------ Seguir con la logica anterior -----
             -- Busca si el supervisor es promotor del cliente
             if v_cod_promotor is not null Then
                Begin
                   Select cod_usu_supervisor
                     into v_supervisor
                     from ba_usuarios
                    where cod_usuario = v_cod_promotor;
                   If nvl(v_supervisor, 'x') = nvl(user,'x')  Then
                      return ('S');
                   Else
                      return ('N');
                   End If;
                Exception
                   When NO_DATA_FOUND Then
                      return ('N');
                End;
             Elsif v_cod_oficial is not null Then
                Begin
                   Select cod_usu_supervisor
                     into v_supervisor
                     from ba_usuarios
                    where cod_usuario = v_cod_oficial;
                   If nvl(v_supervisor, 'x') = nvl(user,'x')  Then
                      return ('S');
                   Else
                      return ('N');
                   End If;
                Exception
                   When NO_DATA_FOUND Then
                      return ('N');
                End;
             Else
                return ('N');
             End If;
          End If;
       end if;
       --- Logica para clientes confidenciales o clientes usuarios
       begin
          -- El cliente corresponde a la oficina del usuario actual, que figura como
          -- encargado de la oficina, se muestra sino sigue...
          Select 'S' into v_puede_ver
            from ba_oficinas
           where cod_usu_encargado = user
             and cod_oficina = v_cod_oficina;
          return ('S');
       exception
          when no_data_found then null;
       end;
       begin
          -- El cliente es del grupo de oficinas(relacion con la oficina del cliente),
          -- y el usuario es el encargado de dicho grupo, se muestra, sino NO.
          Select 'S' into v_puede_ver
            from ba_gru_oficinas g, ba_oficinas o
           where g.cod_usu_encargado = user
             and g.cod_gru_oficina = o.cod_gru_oficina
             and o.cod_oficina = v_cod_oficina;
          return ('S');
       exception
          when no_data_found then
             return ('N');
       end;
     END IF;
end;
/

