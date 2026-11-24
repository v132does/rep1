create or replace function it.FUJ_PRO_TRA_CAJA(p_pedido in varchar2)
  return long is
  v_respuesta long;
  -- Funcion que procesa los pedidos realizados por el cliente JAVA, y responde un texto
  -- con todo el esquema necesario para que el cliente JAVA reaccione correctamente.----
  v_pos             number;
  v_sep             varchar2(1) := '~'; -- separador de campos
  v_pedido          varchar2(2000) := ltrim(rtrim(p_pedido));
  v_cod_usuario     varchar2(15);
  v_clave           varchar2(15);
  v_nro_caja        varchar2(4);
  v_nro_operacion   varchar2(10);
  v_modo            varchar2(1);
  v_cod_transaccion varchar2(4);
  v_parametros      varchar2(2000);
  v_sentencia       varchar2(1000);
  v_cod_respuesta   varchar2(3);
begin

  -- Formato del pedido:
  -- Usuario~Clave~NroCaja~NroOperacion~Tipo(V=Validar/C=Confirmar)~Transaccion~<Parametros>
  -- donde, <Parametros> es opcional.

  -- le saco los dos ultimos caracteres al pedido (son basura)
  v_pedido := substr(v_pedido,1,length(v_pedido)-2);

  -- Analizo el pedido recibido ----------------------------------------------------------
  -- Leo el codigo del usuario
  v_pos := instr(v_pedido,v_sep);
  v_cod_usuario := substr(v_pedido,1,v_pos-1);
  v_pedido := substr(v_pedido,v_pos+1);
  -- Leo la clave del usuario
  v_pos := instr(v_pedido,v_sep);
  v_clave := substr(v_pedido,1,v_pos-1);
  v_pedido := substr(v_pedido,v_pos+1);
  -- Leo el Nro de caja
  v_pos := instr(v_pedido,v_sep);
  v_nro_caja := substr(v_pedido,1,v_pos-1);
  v_pedido := substr(v_pedido,v_pos+1);
 	-- Leo el nro de operacion
  v_pos := instr(v_pedido,v_sep);
  v_nro_operacion := substr(v_pedido,1,v_pos-1);
  v_pedido := substr(v_pedido,v_pos+1);
 	-- Leo el modo de procesamiento V-validacion C-confirmacion
  v_pos := instr(v_pedido,v_sep);
  v_modo := substr(v_pedido,1,v_pos-1);
  v_pedido := substr(v_pedido,v_pos+1);
 	-- Leo la transaccion
  v_pos := instr(v_pedido,v_sep);
  if v_pos = 0 then
     -- no existe parametros
     v_cod_transaccion := v_pedido;
     v_parametros := '';
  else
     -- Leo el parametro
     v_cod_transaccion := substr(v_pedido,1,v_pos-1);
     v_parametros := substr(v_pedido,v_pos+1);
  end if;

  -- Veo que funcion de Caja debe ejecutarse----------------------------------------
  if v_cod_transaccion = '000' then
     -- validacion del Nro de caja
     v_respuesta := fuj_val_caja(v_nro_operacion, v_nro_caja);
  else
     if v_cod_transaccion is not null and v_parametros is null then
        -- validacion del codigo de transaccion (sin parametros)----------------------
        v_respuesta := fuj_val_transaccion(v_nro_operacion, v_nro_caja, v_cod_transaccion);
     elsif v_cod_transaccion is not null and v_parametros is not null then
        -- validacion o Confirmacion de los datos de la transaccion (tiene parametros)
        if v_modo =  'V' then -- Validacion
           v_sentencia := 'Begin '||
                          ' :r := fuj_val_transaccion_'||v_cod_transaccion||
                          '('''||v_nro_operacion||''','''||v_nro_caja||
                          ''','||v_parametros||'); '||
                          'End;';
           v_respuesta := sql_util.ejecute_funcion(v_sentencia);
        elsif v_modo = 'C' then -- confirmacion
           v_sentencia := 'Begin '||
                          ' :r := fuj_pro_transaccion_'||v_cod_transaccion||
                          '('''||v_nro_operacion||''','''||v_nro_caja||
                          ''','||v_parametros||'); '||
                          'End;';
           v_respuesta := sql_util.ejecute_funcion(v_sentencia);
           v_cod_respuesta := substr(v_respuesta,12,3);
           if v_cod_respuesta not in ('000','IMP') then
              -- no se termino bien la operacion, se hace rollback
              rollback;
           end if;   
        end if;
     end if;
  end if;
  -- envio la respuesta --
  return(v_respuesta);
exception
   when others then
       rollback; -- se hace rollback, porque hubo erro grave
       return (v_nro_operacion||'~'||'001'||'~'||'Error: '||sqlerrm);
end FUJ_PRO_TRA_CAJA;
/

