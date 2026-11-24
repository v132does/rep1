CREATE OR REPLACE PACKAGE BODY IT.PAW_BCE is
 --https://itti-digital.atlassian.net/browse/NVB-3811
v_hor_cie_cheques varchar2(08) := fue_obt_val_max_refcodes('HOR_COR_CAMARA','T'); -- hora de cierre fijo para cheques cargo otros bancos.
v_tip_monto       varchar2(01) := 'O'; -- tipo de cheque
v_imp_alt_valor   number(18,2);

c_usu_operativo_emp VARCHAR2(20):='HBANKJ';
c_usu_operativo_fis  VARCHAR2(20):='HBANKF';


--- Autor:  Agustin Meza
-- Creado: 17/sep/2007
---Proposito: Este es el nuevo paquete paw_bce, el cual es copia del original paw_bce, con el nombre
-- temporal paw_bce porque el anterior aun debe permanecer activo por un tiempo

-- Modificiaciones:
-- RAMG: 05/04/2010 - Se anulo el control de que no se vean las cuentas de ahorros combinadas

-----------***  FUNCIONES Y PROCEDIMIENTOS INTERNOS ***------------
procedure lp_reg_operacion(p_nro_cuenta     in varchar2 default null,
                           p_cod_moneda     in varchar2 default null,
                           p_monto          in number   default null,
                           p_nro_cta_contra in varchar2 default null,
                           p_cantidad       in number   default null,
                           p_etiqueta       in varchar2 default null,
                           p_dato           in varchar2 default null,
                           p_etiqueta2      in varchar2 default null,
                           p_dato2          in varchar2 default null,
                           p_observacion    in varchar2 default null,
                           p_dir_ip         in varchar2 default null,
                           p_parametros     in varchar2 default null,
                           p_etiqueta3      in varchar2 default null,
                           p_dato3          in varchar2 default null) is
  PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
begin
   insert into bw_movimientos
     (nro_documento,cod_per_principal  , cod_per_ingreso,   clave,  fec_hora, nro_caja    ,  cod_tip_mensaje , dir_ip,
      cod_respuesta, observacion,
      nro_cuenta, cod_moneda, monto, nro_cta_contra, cantidad,
      etiqueta, dato, etiqueta2, dato2, parametros, etiqueta3, dato3)
   values
     (v_nro_operacion,nvl(v_cod_per_empresa,v_cod_persona), v_cod_persona, substr(p_clave, 1, 12), sysdate, v_nro_terminal, v_cod_operacion, p_dir_ip,
      v_cod_respuesta,p_observacion,
      replace(trim(p_nro_cuenta),chr(13),''), p_cod_moneda, p_monto, replace(trim(p_nro_cta_contra),chr(13),''), p_cantidad,
      p_etiqueta, p_dato, p_etiqueta2, p_dato2, p_parametros,p_etiqueta3,p_dato3);
   commit;
exception
   when others then null;
end;
--obtener el último Nro. de Hoja de Seguridad
function fu_obt_nro_seguridad (p_cod_cliente       in varchar2,
                               p_cod_per_vinculada in varchar2,
                               p_tip_clave         in varchar2) 
return number is
v_hoj_seguridad number(6);
begin
   if p_tip_clave in ('T', 'A') then
      begin
         select a.nro_hoj_seguridad
           into v_hoj_seguridad
           from bw_cla_acciones a
          where a.cod_persona   = p_cod_cliente
            and a.accion        = 'H'
            and a.tip_clave     = p_tip_clave
            and nvl(a.cod_per_vinculada,-1) = nvl(p_cod_per_vinculada,-1)
            and a.fec_insercion = (select max(fec_insercion) 
                                     from bw_cla_acciones 
                                    where cod_persona = p_cod_cliente
                                      and accion      = 'H'
                                      and tip_clave   = p_tip_clave
                                      and nvl(cod_per_vinculada,-1) = nvl(p_cod_per_vinculada,-1))
            and rownum = 1;
                                                                       
         return v_hoj_seguridad;
      exception
         when no_data_found then
            v_hoj_seguridad := null;
            return v_hoj_seguridad;
         when others then
            raise_application_error(-20001,'Error en la tabla (BW_CLA_ACCIONES).'||sqlerrm);
      end;
   else
      raise_application_error(-20003,'Error en la tabla (BW_CLA_ACCIONES), tipo de clave no reconocido.'||sqlerrm);
   end if;
end;

function lf_obt_des_chequera(p_tip_chequera in varchar2)
return varchar2 is
v_retorno varchar2(200);
begin
  select descripcion||' '||substr(p_tip_chequera,3,5)
    into v_retorno
    from cc_tip_chequeras
    where cod_tip_chequera = substr(p_tip_chequera,1,1);
  return v_retorno;
exception
  when others then
     return null;
end;

-- obtiene los datos (campos) de un registros seguen formato de importacion
function fu_obt_dato(p_for_archivo in varchar2, p_nom_tabla in varchar2,
                     p_registro in varchar2,p_campo in varchar2)
return varchar2 is
v_retorno varchar2(300);
v_tip_dato varchar2(100);
v_formato  varchar2(100);
v_pos_inicial number(8);
v_longitud number(8);
v_separador varchar2(1);
v_nro_secuencia number(8);
v_pos_final number(8);
v_funcion   ge_arc_campos.funcion%type;
v_sentencia varchar2(1000);
v_can_decimales number(3);

begin
  select separador
    into v_separador
    from ge_archivos
   where referencia = p_for_archivo
      and rownum =1;

  select tip_dato, formato, pos_inicial, longitud,nro_secuencia, funcion, pos_decimal
    into v_tip_dato, v_formato, v_pos_inicial, v_longitud, v_nro_secuencia, v_funcion,
         v_can_decimales

    from ge_arc_campos
   where referencia = p_for_archivo
     and nom_tabla = p_nom_tabla
     and campo = p_campo;
  if v_separador is null then
     v_retorno := substr(p_registro,v_pos_inicial,v_longitud);
  else
     -- no tiene formato fijo, se busca
     v_pos_inicial := instr(p_registro,v_separador,1,v_nro_secuencia-1)+1;
     v_pos_final   := instr(p_registro,v_separador,1,v_nro_secuencia);
     if v_pos_inicial = 0 then
        raise_application_error(-20056,'No encuentro el separador nro '||v_nro_secuencia||' en '||p_registro);
     elsif v_pos_final = 0 then
         v_pos_final := length(p_registro);
     end if;
     v_longitud := v_pos_final - v_pos_inicial;
     v_retorno := substr(p_registro,v_pos_inicial,v_longitud);

  end if;
  if v_tip_dato = 'VARCHAR2' then
     v_retorno := trim(replace(v_retorno,chr(9),' ')); --reemplazamos el tab (si existe) por espacio
  elsif v_tip_dato = 'NUMBER' then
     v_retorno := replace(trim(v_retorno),',','.');
     if instr(v_retorno,'.') = 0 and v_can_decimales > 0 then
        if instr(v_retorno,'-') > 0 then
           v_retorno := (nvl(to_number(replace(v_retorno,'-','')),0)) / (power(10,v_can_decimales));
           v_retorno := v_retorno * (-1);
        else
           v_retorno := (nvl(to_number(v_retorno),0)) / (power(10,v_can_decimales));
        end if;
     else
        if instr(v_retorno,'-') > 0 then
           v_retorno :=  nvl(to_number(replace(v_retorno,'-','')),0);
           v_retorno := v_retorno * (-1);
        else
           v_retorno :=  nvl(to_number(v_retorno),0);
        end if;
     end if;
  elsif v_tip_dato = 'DATE' then
     v_retorno := to_char(to_date(v_retorno,v_formato),'dd/mm/yyyy');
  end if;
  if v_funcion is not null then -- se procesa el dato
     v_sentencia := 'begin :r := '||replace(v_funcion,'$param',''''||v_retorno||'''')||'; end;';
     v_retorno   := trim(sql_util.ejecute_funcion(v_sentencia));
  end if;
  return v_retorno;
exception
 when others then
    return null;
end;
-- obtiene los datos (campos) de un registros seguen formato de importacion
function fu_obt_dato_dev(p_for_archivo in varchar2, p_nom_tabla in varchar2,
                     p_registro in varchar2,p_campo in varchar2)
return varchar2 is
v_retorno varchar2(300);
v_tip_dato varchar2(100);
v_formato  varchar2(100);
v_pos_inicial number(8);
v_longitud number(8);
v_separador varchar2(1);
v_nro_secuencia number(8);
v_pos_final number(8);
v_funcion   ge_arc_campos.funcion%type;
v_sentencia varchar2(1000);
v_can_decimales number(3);

begin
  select separador
    into v_separador
    from ge_archivos
   where referencia = p_for_archivo
      and rownum =1;

  select tip_dato, formato, pos_inicial, longitud,nro_secuencia, funcion, pos_decimal
    into v_tip_dato, v_formato, v_pos_inicial, v_longitud, v_nro_secuencia, v_funcion,
         v_can_decimales

    from ge_arc_campos
   where referencia = p_for_archivo
     and nom_tabla = p_nom_tabla
     and campo = p_campo;
  if v_separador is null then
     v_retorno := substr(p_registro,v_pos_inicial,v_longitud);
  else
     -- no tiene formato fijo, se busca
     If v_nro_secuencia = 1 Then
       v_pos_inicial := 1;
     Else
       v_pos_inicial := instr(p_registro,v_separador,1,v_nro_secuencia-1)+1;
     End if;

     v_pos_final   := instr(p_registro,v_separador,1,v_nro_secuencia);
     if v_pos_inicial = 0 then
        raise_application_error(-20056,'No encuentro el separador nro '||v_nro_secuencia||' en '||p_registro);
     elsif v_pos_final = 0 then
         v_pos_final := length(p_registro);
     end if;
     v_longitud := v_pos_final - v_pos_inicial;
     v_retorno := substr(p_registro,v_pos_inicial,v_longitud);

  end if;
  if v_tip_dato = 'VARCHAR2' then
     v_retorno := trim(replace(v_retorno,chr(9),' ')); --reemplazamos el tab (si existe) por espacio
  elsif v_tip_dato = 'NUMBER' then
     v_retorno := replace(trim(v_retorno),',','.');
     if instr(v_retorno,'.') = 0 and v_can_decimales > 0 then
        if instr(v_retorno,'-') > 0 then
           v_retorno := (nvl(to_number(replace(v_retorno,'-','')),0)) / (power(10,v_can_decimales));
           v_retorno := v_retorno * (-1);
        else
           v_retorno := (nvl(to_number(v_retorno),0)) / (power(10,v_can_decimales));
        end if;
     else
        if instr(v_retorno,'-') > 0 then
           v_retorno :=  nvl(to_number(replace(v_retorno,'-','')),0);
           v_retorno := v_retorno * (-1);
        else
           v_retorno :=  nvl(to_number(v_retorno),0);
        end if;
     end if;
  elsif v_tip_dato = 'DATE' then
     v_retorno := to_char(to_date(v_retorno,v_formato),'dd/mm/yyyy');
  end if;
  if v_funcion is not null then -- se procesa el dato
     v_sentencia := 'begin :r := '||replace(v_funcion,'$param',''''||v_retorno||'''')||'; end;';
     v_retorno   := trim(sql_util.ejecute_funcion(v_sentencia));
  end if;
  return v_retorno;
exception
 when others then
    return null;
end;

function lf_obt_permisos(p_cod_persona in varchar2, p_cod_perfil in varchar2, p_cod_operacion in varchar2)
  return varchar2 is
  v_retorno varchar2(10);
begin
  select trim(decode(consulta,'S','C','')||decode(ingresa,'S','I','')||decode(autoriza,'S','A',''))
    into v_tip_mensaje
    from bw_tip_mensajes
   where cod_tip_mensaje = p_cod_operacion;
  begin
      -- busco primero especifico para la empresa
      select trim(decode(consulta,'S','C','')||decode(ingresa,'S','I','')||decode(autoriza,'S','A','')),
             nvl(can_firmas,0)
        into v_retorno, v_can_aut_requeridas
        from bw_rol_permisos
       where cod_perfil = p_cod_perfil
         and cod_tip_mensaje = p_cod_operacion
         and cod_persona = p_cod_persona;
  exception
     when no_data_found then
        -- busco los permisos generales para el perfil
        select trim(decode(consulta,'S','C','')||decode(ingresa,'S','I','')||decode(autoriza,'S','A','')),
               nvl(can_firmas,0)
          into v_retorno, v_can_aut_requeridas
          from bw_rol_permisos
         where cod_perfil = p_cod_perfil
           and cod_tip_mensaje = p_cod_operacion
           and cod_persona is null;
  end;
  if v_can_aut_requeridas > 0 and fu_caj_homebanking(v_nro_terminal) = 'N' /*v_nro_terminal != '999'*/ then
     -- operacion no permitida en autoservicios por requerir autorizacion
     v_cod_respuesta := paw_bce.v_cod_ope_no_permitida;
  end if;

  --if v_cod_per_empresa is null then
  --   v_can_aut_requeridas := 0; -- no tiene autorizacion pendiente cuando es la persona fisica
  --end if;
  ---
  return v_retorno;
exception
  when others then
    return v_retorno;
end;
--
function lf_obt_tot_transacciones(p_nro_cuenta in varchar2,
                                  p_cod_tra_padre in number,
                                  p_cod_tip_mensaje in varchar2)
  return number is
v_total number(18,2) := 0;
begin
  select nvl(sum(monto),0)
    into v_total
    from ge_movimientos
   where nro_cuenta = p_nro_cuenta
     and estado = 'N'
     and reversado = 'N'
     and cod_transaccion = 503
     and concepto like 'Transf. a % desde %'
     and cod_tra_padre = p_cod_tra_padre
     and trunc(fec_insercion) = trunc(sysdate);

  select nvl(v_total,0) + nvl(sum(monto),0)
    into v_total
    from ge_movimientos_noc
   where nro_cuenta = p_nro_cuenta
     and estado = 'N'
     and reversado = 'N'
     and cod_transaccion = 503
     and concepto like 'Transf. a % desde %'
     and cod_tra_padre = p_cod_tra_padre
     and trunc(fec_insercion) = trunc(sysdate);

  select nvl(v_total,0) + nvl(sum(monto),0)
    into v_total
    from bw_mov_pendientes
   where nro_cuenta = p_nro_cuenta
     and cod_tip_mensaje = p_cod_tip_mensaje
     and dato2 like 'Transf. a % desde %'
     and estado = 'P'
     and trunc(fec_insercion) = trunc(sysdate);


  return v_total;
end;
-- valida si una cuenta pertenece a un documento dado
function lf_cta_valida(p_nro_cuenta varchar2, p_nro_documento in varchar2)
return varchar2 is
v_sino varchar2(01) := 'N';
v_tip_persona varchar2(1);
v_cod_persona varchar2(20);
v_nro_documento varchar2(20) := p_nro_documento;
v_per_otr_cta varchar2(10);
v_can_anterior number;
begin

    if v_nro_documento is null then
       select nro_documento
         into v_nro_documento
         from ba_personas
        where cod_persona = nvl(v_cod_per_empresa,v_cod_persona);
    else
       -- veo si tiene permiso para transferencia 039 a otras cuentas
       v_can_anterior := v_can_aut_requeridas;
       v_per_otr_cta := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '039');
       v_can_aut_requeridas := v_can_anterior;
       if v_per_otr_cta is null then
          v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
          v_sino := 'N';
          return v_sino;
       end if;
    end if;

    select tipo, a.cod_persona
      into v_tip_persona, v_cod_persona
      from ba_personas b, ge_cta_clientes a
     where a.nro_cuenta = p_nro_cuenta
       and a.relacion = 'P'
       and a.cod_persona = b.cod_persona;
    begin
        if v_tip_persona = 'J' then -- empresa
        -- busqueda por principal para ver si es el documento de la empresa
            select 'S'
              into v_sino
              from ba_personas a
             where a.cod_persona = v_cod_persona
               and a.nro_documento = v_nro_documento;
        else -- la cuenta es de una persona fisica
            select 'S'
              into v_sino
              from  ba_personas b
             where b.nro_documento = v_nro_documento
               and b.cod_persona in (select x.cod_persona
                             from ge_cta_clientes x
                            where x.nro_cuenta = p_nro_cuenta
                              and x.cod_persona = b.cod_persona)
               and rownum = 1; -- primero que encuentre
        end if;
    end;
   return v_sino;
exception
   when others then
       v_sino := 'N';
       return v_sino;
end;
--
function lf_obt_cta_limpia(p_nro_cta_especifica varchar2)
return varchar2 is
v_nro_cta_especifica varchar2(30) := replace(replace(replace(trim(p_nro_cta_especifica),'.','-'),' ','-'),'/','-');
v_pos number;
begin
  if v_nro_cta_especifica is not null then
    if (instr(v_nro_cta_especifica,'-') > 0 or instr(v_nro_cta_especifica,' ') > 0) then
       -- se extrae los guiones de la cuenta
       If v_cod_operacion = '031' then -- or (v_cod_operacion = '010' /*and v_tip_consulta = '031'*/) then
          -- Si es pago de prestamos solo debe quitarle el guion y el espacio si tiene
          v_nro_cta_especifica := trim(replace(replace(v_nro_cta_especifica, '-',''), ' ',''));
       Else
          v_pos := instr(v_nro_cta_especifica,'-',-1);
          if v_pos > 0 then
             v_nro_cta_especifica := to_number(substr(v_nro_cta_especifica,v_pos+1));
          end if;
       End if;
    elsif length(v_nro_cta_especifica) = 16 then
       -- es un tarjeta de credito, busco y reemplazo el dato
       begin
          select a.nro_cuenta
            into v_nro_cta_especifica
            from ge_cta_clientes a, ta_tarjetas b
           where b.nro_tarjeta = trim(v_nro_cta_especifica)
             and b.nro_cuenta = a.nro_cuenta
             and a.cod_persona = nvl(v_cod_per_empresa, v_cod_persona);
       exception
         when no_data_found then
           select b.nro_cuenta
            into v_nro_cta_especifica
            from ta_tarjetas b
           where b.nro_tarjeta = trim(v_nro_cta_especifica)
             and vigente = 'S'
             and rownum = 1;
       end;
    elsif substr(v_nro_cta_especifica,1,2) = '00' then
       v_nro_cta_especifica := to_number(v_nro_cta_especifica);
   end if;
  end if;
  return v_nro_cta_especifica;
end;


-- funcion que encripta y devuelve el valor encriptado de una palabra en formato md5
function fu_enc_md5(p_encripta varchar2) return varchar2 is
  Result varchar2(2000);
begin

  Result := lower(dbms_obfuscation_toolkit.md5(input => utl_raw.cast_to_raw((p_encripta))));
  return(Result);
end fu_enc_md5;

function fu_enc_sha1(p_encripta varchar2) return varchar2 is
  v_resp varchar2(2000);
begin
  v_resp := lower(DBMS_CRYPTO.Hash(src => utl_raw.cast_to_raw(p_encripta) , typ => DBMS_CRYPTO.HASH_SH1));
  return v_resp;
end;


-- funcion que devuelve si una cuenta tiene o no cheque devuelto --
function lf_obt_che_devuelto(p_nro_cuenta in varchar2)
  return varchar2 is
v_cantidad number;
v_fec_anterior date := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual, v_cod_ofi_origen, 1);
begin
   select count(*)
     into v_cantidad
     from ge_movimientos
    where nro_cuenta = p_nro_cuenta
      and cod_mod_padre = 4
      and cod_mad_padre = 41
      and cod_tra_padre = 321
      and cod_transaccion in (522,503,182)
      and reversado = 'N'
      and estado = 'N'
      and rownum = 1;
   if v_cantidad > 0 then
      return 'S';
   else
      return 'N';
   end if;
end;
function fu_es_conjunta(p_nro_cuenta in varchar2)
return varchar2 is
v_can_conjunta  number;
v_cod_principal ba_personas.cod_persona%type;
begin
   -- veo si la cuenta no es conjunta
   select count(*) into v_can_conjunta
     from ge_cta_clientes
    where nro_cuenta = p_nro_cuenta
      and relacion = 'Y'
      and rownum = 1;
   if v_can_conjunta > 0 and nvl(v_can_aut_requeridas,0) = 0 then
     /* no requiere autorizacion y la cuenta es conjunta, no debe acceder*/
      return 'S';
   else
      return 'N';
   end if;
/*      -- Obtengo el principal.
      Select cod_persona
        into v_cod_principal
        from ge_cta_clientes
       where nro_cuenta = p_nro_cuenta
         and relacion = 'P';
      --
      If pag_gen.FU_ES_PER_FISICA(v_cod_principal) = 'N' and nvl(v_cod_per_empresa,v_cod_persona) != v_cod_principal then
         return 'S';
      Else
         return 'N';
      End if;
   end if;*/
end;
---
function fu_es_juridica(p_nro_cuenta in varchar2)
return varchar2 is
v_can_conjunta  number;
v_cod_principal ba_personas.cod_persona%type;
begin
    --- Obtengo el principal.
    Select cod_persona
      into v_cod_principal
      from ge_cta_clientes
     where nro_cuenta = p_nro_cuenta
       and relacion = 'P';
    --
    If pag_gen.FU_ES_PER_FISICA(v_cod_principal) = 'N' and nvl(v_cod_per_empresa,v_cod_persona) != v_cod_principal then
       return 'S';
    Else
       return 'N';
    End if;
end;
-- devuelve el nro de tarjeta para una cuenta
function lf_obt_nro_tarjeta(p_nro_cuenta in varchar2)
   return varchar2 is
--v_retorno varchar2(20);
begin
  return fu_obt_nro_tarjeta(p_nro_cuenta, v_cod_persona, v_cod_per_empresa);
end;
/*begin
  select nro_tarjeta
    into v_retorno
    from ta_tarjetas
   where nro_cuenta = p_nro_cuenta
     and vigente = 'S'
     and cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
     and rownum = 1;
  return v_retorno;
exception
  when no_data_found then
     begin
        -- puede ser tarjeta empresa
        select nro_tarjeta
          into v_retorno
          from ta_tarjetas
         where nro_cuenta = p_nro_cuenta
           and vigente = 'S'
           and rownum = 1;
        return v_retorno;
     exception
        when no_data_found then
           -- puede que todas sean NO vigente
           select MAX(nro_tarjeta)
             into v_retorno
             from ta_tarjetas
            where nro_cuenta = p_nro_cuenta;
           return v_retorno;  
     end; 
  when others then
     return null;
end;*/

-- Funcion para obtener el numero de tarjeta
function fu_obt_nro_tarjeta(p_nro_cuenta      in ge_cuentas.nro_cuenta%type, 
                            p_cod_persona     in ba_personas.cod_persona%type, 
                            p_cod_per_empresa in ba_personas.cod_persona%type)
  return varchar2 is
  v_retorno ta_tarjetas.nro_tarjeta%type := NULL;
begin
  -- obtenemos el plastico
  begin
    BEGIN
      SELECT t.nro_tarjeta
        INTO v_retorno
        FROM ta_tarjetas t
       WHERE t.nro_cuenta = p_nro_cuenta
         AND t.cod_persona = p_cod_persona
         AND vigente = 'S' -- vigente
         AND rownum = 1
       order by t.fec_vencimiento desc;
    EXCEPTION
      WHEN no_data_found THEN
        SELECT t.nro_tarjeta
          INTO v_retorno
          FROM ta_tarjetas t
         WHERE t.nro_cuenta = p_nro_cuenta
           AND t.cod_persona = p_cod_persona
           AND t.fec_vencimiento =
               (select max(a.fec_vencimiento)
                  from ta_tarjetas a
                 where a.nro_cuenta = p_nro_cuenta
                   and a.cod_persona = p_cod_persona)
           AND rownum = 1
         order by t.fec_vencimiento desc;
    END;
  
  exception
    when no_data_found then
      -- PUEDE SER BANCA EMPRESAS --
      BEGIN
        SELECT t.nro_tarjeta
          INTO v_retorno
          FROM ta_tarjetas t
         WHERE t.nro_cuenta = p_nro_cuenta
           AND t.cod_persona = p_cod_per_empresa
           AND vigente = 'S' -- vigente
           AND rownum = 1
         order by t.fec_vencimiento desc;
      EXCEPTION
        WHEN no_data_found THEN
          SELECT t.nro_tarjeta
            INTO v_retorno
            FROM ta_tarjetas t
           WHERE t.nro_cuenta = p_nro_cuenta
             AND t.cod_persona = p_cod_per_empresa
             AND t.fec_vencimiento =
                 (select max(a.fec_vencimiento)
                    from ta_tarjetas a
                   where a.nro_cuenta = p_nro_cuenta
                     and a.cod_persona = p_cod_per_empresa)
             AND rownum = 1
           order by t.fec_vencimiento desc;
      END;
  end;
  return v_retorno;
exception
  when others then
    return null;
end;

function fu_obt_nro_sec_sueldo(p_cod_ente   in ge_pag_sueldos.cod_ente%type, 
                               p_fec_actual in ge_pag_sueldos.fec_envio%type) return number is
v_nro_archivo     number;
v_aux_nro_archivo number;
begin
   begin
      -- obtenemos la maxima secuencia del temporal
      select distinct nvl(max(ge.nro_archivo), 0)+1
        into v_nro_archivo
        from ge_pag_sueldos_tmp ge
       where ge.cod_ente = p_cod_ente
         and trunc(ge.fec_proceso) = trunc(p_fec_actual);
   exception
      when others then
         v_nro_archivo := 1; -- BBVADES-2376
   end;
     
   begin
      -- obtenemos la maxima secuencia del pago
      select distinct nvl(max(gs.nro_secuencia), 0)+1
        into v_aux_nro_archivo
        from ge_pag_sueldos gs
       where gs.cod_ente = p_cod_ente
         and gs.fec_proceso = p_fec_actual;
   exception
      when others then
         v_aux_nro_archivo := 1;
   end;
   -- 
   if v_aux_nro_archivo > v_nro_archivo then
      v_nro_archivo := v_aux_nro_archivo;
   end if;
   
   begin
      -- obtenemos la maxima secuencia de errores
      select distinct nvl(max(se.nro_secuencia), 0)+1
        into v_aux_nro_archivo
        from ge_pag_sueldos_err se
       where se.cod_ente = p_cod_ente
         and se.fec_proceso = p_fec_actual;
   exception
      when others then
         v_aux_nro_archivo := 1;
   end;
   
   if v_aux_nro_archivo > v_nro_archivo then
      v_nro_archivo := v_aux_nro_archivo;
   end if;
   
   -- obtenemos la maxima secuencia de lotes
   v_aux_nro_archivo := pag_sue.fu_obt_sig_nro_secuencia(p_cod_ente, p_fec_actual);
            
   if v_aux_nro_archivo > v_nro_archivo then
      v_nro_archivo := v_aux_nro_archivo;
   end if;
   -- incremento la secuencia
   --v_nro_archivo := v_nro_archivo + 1 ;
   
   return v_nro_archivo;
end;

-- devuelve el codigo del tipo de cuenta
function fu_tip_cuenta(p_cod_modulo in number,
                       p_cod_modalidad in number)
   return char is
v_cod_tip_cuenta char(2);
v_mad_aho         ge_par_dinamicos.val_parametro%type :=fug_obt_pardinamico('MAD_TIP_AHO_BANWEB');
begin
  if p_cod_modulo = 3 then
     -- ahorros
     if instr(v_mad_aho, '#'||p_cod_modalidad||'#' ) > 0 then
        v_cod_tip_cuenta := 'AH';
     elsif p_cod_modalidad in (32,37) then
        v_cod_tip_cuenta := 'AP';
     elsif p_cod_modalidad = 33 then
        v_cod_tip_cuenta := 'CD';
     elsif p_cod_modalidad = 34 then
        v_cod_tip_cuenta := 'TI';
     elsif p_cod_modalidad = 36 then
        v_cod_tip_cuenta := 'BS';
     elsif p_cod_modalidad = 38 then
        v_cod_tip_cuenta := 'AP'; --AIU-736
     end if;
  elsif p_cod_modulo = 4 then
     -- cuentas corrientes
     v_cod_tip_cuenta := 'CC';
  elsif p_cod_modulo = 5 then
     -- Tarjetas
     v_cod_tip_cuenta := 'TJ';
  elsif p_cod_modulo = 6 then
     -- prestamos
     v_cod_tip_cuenta := 'PT';
  elsif p_cod_modulo = 8 then
     -- comercio exterior
     v_cod_tip_cuenta := 'CX';
  end if;

  return v_cod_tip_cuenta;
end;

-- genera movimientos en movimientos
procedure lp_ins_movimiento
   (p_cod_mod_cta       in number,
    p_cod_mad_cta       in number,
    p_cod_ofi_cta       in number,
    p_nro_cuenta        in varchar2,
    p_cod_moneda        in varchar2,
    p_cod_tra_padre     in number,
    p_cod_transaccion   in number,
    p_nro_documento     in number,
    p_monto             in number,
    p_afe_caja          in varchar2 default 'N',  -- E-efectivo C-Cheq.Ntro.bco O-Cheq.otro.bco N-no afecta
    p_es_mov_noc        in varchar2 default null,
    p_cod_retencion     in number   default null,
    p_fec_fin_retencion in date     default null,
    p_concepto          in varchar2 default null,
    p_cotizacion        in number   default null,
    p_cod_mod_padre     in number   default null,
    p_cod_mad_padre     in number   default null)

 is
r_gmovi ge_movimientos%rowtype;
v_can_movimientos number(8) := 0;
v_ins_movimiento  varchar2(1) := 'N';
v_can_intentos    number := 1;
v_err_movimiento  varchar2(4000);
begin
     -- veo posible duplicacion de nros de boleta
     begin
        if nvl(p_es_mov_noc,v_es_mov_noc) = 'S' then
          select count(*)
            into v_can_movimientos
            from ge_movimientos_noc
           where nro_cuenta = p_nro_cuenta
             and cod_transaccion = p_cod_transaccion
             and nro_documento = p_nro_documento
             and cod_retencion = p_cod_retencion
             and rownum = 1;
        else
          select count(*)
            into v_can_movimientos
            from ge_movimientos
           where nro_cuenta = p_nro_cuenta
             and cod_transaccion = p_cod_transaccion
             and nro_documento = p_nro_documento
             and cod_retencion = p_cod_retencion
             and rownum = 1;
        end if;
     exception
        when others then
           v_can_movimientos := 0;
     end;
     if v_can_movimientos > 0 then
        -- ya se ingreso la boleta, se debe rechazar
        v_cod_respuesta := paw_bce.v_cod_ped_duplicado;
     else
        -- movimiento puede ser ingresado
         r_gmovi.cod_modulo      := p_cod_mod_cta;
         r_gmovi.cod_modalidad   := p_cod_mad_cta;
         r_gmovi.cod_oficina     := p_cod_ofi_cta  ;
         r_gmovi.nro_cuenta      := p_nro_cuenta  ;
         r_gmovi.cod_moneda      := p_cod_moneda   ;
         r_gmovi.cod_usuario     := v_cod_usuario;
         r_gmovi.hora            := v_hor_actual;
         r_gmovi.fecha           := v_fec_actual;
         -- Aumento la secuencia
         v_nro_secuencia         := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.fec_valor       := v_fec_valor;
         r_gmovi.cod_tra_padre   := p_cod_tra_padre;
         r_gmovi.cod_mod_padre   := nvl(p_cod_mod_padre,9);
         r_gmovi.cod_mad_padre   := nvl(p_cod_mad_padre,91);
         r_gmovi.cod_transaccion := p_cod_transaccion;
         r_gmovi.monto           := p_monto;
         r_gmovi.nro_documento   := p_nro_documento;
         r_gmovi.cotizacion      := p_cotizacion;
         IF p_cotizacion IS NOT NULL THEN
            r_gmovi.mto_equ_local := nvl(r_gmovi.monto,0) * nvl(p_cotizacion,0);
         ELSE
            r_gmovi.mto_equ_local := null;
         END IF;
         r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := p_concepto;
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.nro_caja        := v_nro_terminal;
         --
         r_gmovi.cod_retencion     := p_cod_retencion;
         r_gmovi.fec_fin_retencion := p_fec_fin_retencion;
         /*
         || DYDMR-773 ERROR EN TAS - SC 5610
         || Error de PK desde el TAS por tener mismo usuario, fecha y hora
         */
         while v_ins_movimiento = 'N' and v_can_intentos <= 10 loop
            begin
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, nvl(p_es_mov_noc,v_es_mov_noc));
               v_ins_movimiento := 'S';
            exception
               when others then
                  v_hor_actual     := FUG_OBT_HOR_DISPONIBLE(v_fec_actual,
                                                             v_hor_actual,
                                                             user,
                                                             v_es_mov_noc);
                  r_gmovi.hora     := v_hor_actual;
                  v_ins_movimiento := 'N';
                  v_can_intentos   := v_can_intentos + 1;
                  v_err_movimiento := sqlerrm;
            end;
         end loop;
         if v_ins_movimiento = 'N' then
            raise_application_error(-20000, v_err_movimiento);
         end if;
         ---
         if nvl(p_afe_caja,'N') <> 'N' then
            -- genero el movimiento en caja
            if v_es_mov_noc = 'S' then
              insert into cj_movimientos_noc
                 (fecha, hora, cod_usuario, nro_secuencia,
                  cod_tra_padre, cod_mod_padre, cod_mad_padre,
                  cod_oficina, cod_moneda, nro_caja,
                  nro_documento, nro_cuenta, monto, tip_monto, tipo)
              values
                 (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
                  p_cod_tra_padre, nvl(p_cod_mod_padre,9), nvl(p_cod_mad_padre,91),
                  v_cod_ofi_origen, p_cod_moneda, to_number(v_nro_terminal),
                  p_nro_documento, p_nro_cuenta, p_monto, p_afe_caja, 'D');  --es debito
            else
              insert into cj_movimientos
                 (fecha, hora, cod_usuario, nro_secuencia,
                  cod_tra_padre, cod_mod_padre, cod_mad_padre,
                  cod_oficina, cod_moneda, nro_caja,
                  nro_documento, nro_cuenta, monto, tip_monto, tipo)
              values
                 (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
                  p_cod_tra_padre, nvl(p_cod_mod_padre,9), nvl(p_cod_mad_padre,91),
                  v_cod_ofi_origen, p_cod_moneda, to_number(v_nro_terminal),
                  p_nro_documento, p_nro_cuenta, p_monto, p_afe_caja, 'D');  --es debito

            end if;
         end if;
     end if;
end;
-- fin de la insercion de movimientos

-- retorna el saldo actual de una cuenta
function fu_obt_sal_actual(p_cod_modulo    in number,
                           p_cod_modalidad in number,
                           p_nro_cuenta    in varchar2)
   return number is
v_sal_actual number;
v_error        VARCHAR2(1);
v_msj_error    VARCHAR2(2000);
begin

  if p_cod_modulo in (3,4) then
     -- cuentas pasivas
     pag_cta.pr_obt_cuenta(p_nro_cuenta);
     
     IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
       prg_obt_sal_atm_cierre(p_nro_cuenta,
                              pag_cta.g_ctas.sal_disponible,
                              pag_cta.g_ctas.sal_actual,
                              pag_cta.g_ctas.sal_retenido,
                              pag_cta.g_ctas.sal_bloqueado,
                              v_error,
                              v_msj_error);
     END IF; 
     
     v_sal_actual := pag_cta.FU_SAL_DISPONIBLE;
  elsif p_cod_modulo = 5 then
     -- Tarjetas
    select nvl(lin_credito,0) -
           (nvl(b.sal_facturar,0)+
           nvl(b.sal_facturado,0)+
           nvl(b.sal_financiado,0)+
           nvl(b.sal_cuo_pendientes,0))
      into v_sal_actual
      from ta_cta_tarjetas b
     where b.nro_cuenta = p_nro_cuenta;
  elsif p_cod_modulo = 6 then
     -- prestamos
    select nvl(b.sal_capital,0) + nvl(b.sal_int_adelantado,0)
      into v_sal_actual
      from pr_cta_prestamos b
     where b.nro_cuenta = p_nro_cuenta;
  elsif p_cod_modulo = 8 then
     -- comercio exterior
     v_sal_actual :=  0;
  end if;
  return v_sal_actual;
exception
  when others then
     return 0; -- saldo 0(cero)
end;

-- devuelve el indicador del horario de
procedure lp_ver_horario is
  v_est_modulo ba_modulos.estado%type;
begin
  v_horario := 'D'; -- Dia normal
  v_es_mov_noc  := 'N'; -- Para grabar en las tablas nocturnas
  v_es_cta_noc  := 'N';
  v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
  v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);

  If v_est_modulo in (6) Then  -- En cierre.
     v_cod_respuesta := paw_bce.v_cod_sis_cierre;
  elsif v_est_modulo = 2 Then -- El modulo esta abierto
     -- Verifica la hora --
     if sysdate > v_ult_cierre and trunc(v_ult_cierre) = v_fec_actual then
        v_horario := 'T'; -- Tarde
        v_fec_actual := pag_cal.FU_OBT_FEC_HABIL(v_fec_actual+1, 1, v_cod_ofi_origen);
        v_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
     end if;
  else
     v_horario := 'N'; -- Noche
     if v_est_modulo <> 1 then
        v_fec_actual := pag_cal.FU_OBT_FEC_HABIL(v_fec_actual+1, 1, v_cod_ofi_origen);
     end if;
     v_es_mov_noc  := 'S'; -- Para grabar en las tablas nocturnas
     v_es_cta_noc  := 'S'; -- Solo para que llavee la cuenta nocturna
  end if;
  v_fec_valor       := trunc(sysdate); --v_fec_actual;
  pag_cta.g_horario := v_horario;
end lp_ver_horario;

-- actualizar fecha de pago a proveedores
-- dato2 es la columna que se utiliza para indicar la fecha de pago 
-- cuando el tipo de mensaje de 075 - Pago a proveedores
procedure pr_act_fec_pag_pendiente(p_nro_documento in bw_mov_pendientes.nro_documento%type,
                                   p_cod_persona   in bw_mov_pendientes.cod_per_principal%type,
                                   p_fec_pago      in bw_mov_pendientes.dato2%type) is
begin
  update bw_mov_pendientes
     set dato2 = p_fec_pago
   where nro_documento = p_nro_documento
     and cod_per_principal = p_cod_persona;
end;

-- devuelve el mensaje para el cliente
function lf_obt_mensaje(p_cod_persona varchar2)
return varchar2 is
v_mensaje  varchar2(500);
cursor msjs is
  select substr(mensaje,1,300) mensaje
    from ge_msj_bca_ele
   where trunc(sysdate) between fec_desde and fec_hasta
     and (cod_persona = p_cod_persona or cod_persona is null)
   order by nvl(cod_persona,'#') desc,fec_desde desc;
begin
  open msjs;
  fetch msjs into v_mensaje;
  close msjs;
  return v_mensaje;
end;

-- devuelve los datos alfanuméricos
FUNCTION lf_obt_alfanumerico(p_parametro in varchar2,
                             p_longitud  in number) 
  return varchar2 is
begin
  return substr(regexp_replace(trim(p_parametro), '([^[:alnum:] ])', ''), 1, p_longitud);
end;

-- devuelve el campo char formateado
function lf_for_char(p_dato in varchar2,
                     p_longitud in number)
   return char is
begin
  return substr(rpad(nvl(p_dato,' '),p_longitud,' '),1,p_longitud);
end;

-- devuelve el campo date formateado
function lf_for_date(p_dato in date)
   return char is
begin
  return rpad(nvl(to_char(p_dato,'ddmmyyyy'),' '),8,' ');
end;

-- devuelve el campo monto formateado
function lf_for_money(p_dato in number,
                      p_longitud in number default 16)
   return varchar2 is
begin
  return lpad(ltrim(to_char(nvl(p_dato,0),'99999999999999.99')),nvl(p_longitud,16),' ');
end;

-- devuelve el campo numero formateado
function lf_for_number(p_dato in number,
                      p_longitud in number default 3)
   return char is
begin
  return lpad(ltrim(to_char(nvl(p_dato,0),'9999999999999')),p_longitud,'0');
end;
-- funcion que controla la cuenta origen corresponda a la persona
function lf_val_cta_origen(p_nro_cuenta in varchar2,
                           p_cod_persona in varchar2)
  return varchar2 is
v_sino varchar(1) := 'N';
begin
  select 'S'
    into v_sino
    from ge_cta_clientes
   where nro_cuenta = p_nro_cuenta
     and cod_persona = p_cod_persona
     and rownum = 1;
  return v_sino;
exception
   when others then
        v_sino := 'N';
        return v_sino;

end;

procedure lp_val_tas_texto(p_texto in out varchar2) is
--Procedimiento local que reemplaza los caracteres con acento
--DYDMR-4886
begin
  p_texto:=replace(substr(upper(p_texto), 1, 1000),'Á','A');
  p_texto:=replace(p_texto,'É','E');
  p_texto:=replace(p_texto,'Í','I');
  p_texto:=replace(p_texto,'Ó','O');
  p_texto:=replace(p_texto,'Ú','U');
  p_texto:=replace(p_texto,'Ñ','N');
end;

/* función que controla si p_fec_pago excede la hora de cierre 
 para pago a proveedores, si es así actualiza p_fec_pago l día hábil siguiente 
*/
function fu_ver_hor_cie_proveedor(p_fec_pago in out date)
  return boolean is
v_cam_fecha boolean := false;
v_hor_cie_pag_proveedor varchar2(19) := to_char(sysdate,'DD/MM/YYYY')||' '||nvl(substr(trim(fug_obt_pardinamico('HOR_CIE_PROVEEDOR_HB')),1,5),'14:30')||':00';

begin
  if p_fec_pago = trunc(sysdate) then
    begin
      if sysdate > to_date(v_hor_cie_pag_proveedor, 'dd/mm/yyyy hh24:mi:ss') then
        p_fec_pago := pag_cal.FU_OBT_FEC_HABIL(p_fec_pago + 1, 1, paw_bce.v_cod_ofi_origen);
        v_cam_fecha := true;
      end if;
    exception
      when others then
        null;   
    end;      
  end if;
  return v_cam_fecha;
end;

-- Función que valida que la tarjeta de crédito pertenezca a la persona
function lf_val_tar_origen(p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                           p_cod_persona in ge_clientes.cod_persona%type)
  return varchar2 is
v_sino varchar2(1);
v_nro_cuenta ta_tarjetas.nro_cuenta%type;
begin
  begin
    select t.nro_cuenta
      into v_nro_cuenta
      from ta_tarjetas t
     where t.nro_tarjeta = p_nro_tarjeta;

    select 'S'
      into v_sino
      from ta_tarjetas
     where nro_cuenta = v_nro_cuenta
       and cod_persona = p_cod_persona
       and rownum=1;
 exception
    when others then
      v_sino := 'N';
  end;
  return v_sino;       
end;

/* Función que valida que el código de persona del movimiento pendiente
   pertenezca a la persona que esta queriendo consultar el documento pendiente */
FUNCTION fu_val_per_pendiente(p_nro_documento IN bw_mov_pendientes.nro_documento%TYPE,
                              p_cod_persona   IN ge_clientes.cod_persona%TYPE)
RETURN varchar2 is
   v_sino varchar2(1);
BEGIN
   BEGIN
      SELECT 'S'
         INTO v_sino
      FROM bw_mov_pendientes
      WHERE nro_documento = p_nro_documento
         AND cod_per_principal = p_cod_persona
         AND ((cod_tip_mensaje NOT IN ('070','075') AND TRUNC(sysdate) = TRUNC(fec_insercion))
                     OR (cod_tip_mensaje IN ('070','075') AND TRUNC(SYSDATE) >= decode(fug_es_date(dato2), 'S',to_date(dato2, 'DD/MM/YYYY'), to_date('01/01/1900', 'DD/MM/YYYY') ) ));
                --- OR (cod_tip_mensaje IN ('070','075') AND TRUNC(SYSDATE) <= to_date(dato2, 'DD/MM/YYYY') ));
   EXCEPTION
      WHEN OTHERS THEN
         v_sino := 'N';
   END;
   RETURN v_sino;
END;

/* Función que valida que el código de persona este vinculada a la empresa */
function fu_val_per_vinculada(p_cod_per_empresa in ge_clientes.cod_persona%type,
                              p_cod_persona     in ge_clientes.cod_persona%type)
  return varchar2 is
v_sino varchar2(1) := 'N';
begin
  begin 
    if pag_gen.fu_es_per_fisica(p_cod_per_empresa) = 'N' then
      select 'S'
        into v_sino
        from ba_vinculos
       where cod_per_vinculo = p_cod_persona
         and cod_persona = p_cod_per_empresa;
    end if;   
  exception
    when too_many_rows then
      v_sino := 'S';
    when others then
      null;
  end;
  return v_sino;
end;

-- Función que indica si la operacion se puede realizar
function fu_ver_operacion(p_nro_cuenta      in ge_cuentas.nro_cuenta%type,
                          p_monto           in ge_movimientos.monto%type,
                          p_cod_transaccion in ge_movimientos.cod_transaccion%type,
                          p_cod_tra_padre   in ge_movimientos.cod_tra_padre%type,
                          p_tip_movimiento  in varchar2) 
  return varchar2 is
v_cod_modulo     ge_cuentas.cod_modulo%type;
v_cod_modalidad  ge_cuentas.cod_modalidad%type;
v_cod_oficina    ge_cuentas.cod_oficina%type;
v_cod_moneda     ge_cuentas.cod_moneda%type;
v_procesa        varchar2(1) := 'N';
v_nvo_estado     varchar2(1) := null;
v_sal_disponible ge_movimientos.monto%type;
begin
  -- obtenemos los datos de la cuenta
  select cod_modulo, cod_modalidad, cod_oficina, cod_moneda
    into v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda
    from ge_cuentas
   where nro_cuenta = p_nro_cuenta;
  -- verificamos si la operación se puede realizar               
  pag_cta.pr_ver_operacion(p_nro_cuenta,
                           p_cod_tra_padre,
                           v_cod_modulo,
                           v_cod_modalidad,
                           p_tip_movimiento,
                           v_cod_moneda,
                           p_monto,
                           v_cod_oficina,
                           v_cod_modulo,
                           v_cod_modalidad,
                           v_nvo_estado,
                           v_sal_disponible,
                           v_procesa,
                           p_cod_transaccion);
  return v_procesa;
exception
  when others then
    return 'N';
end;

-- BSEVOCORE-583 procedimiento de manejo de corte/cierre parcial TAS ITGF
procedure pr_act_corte  is
Begin
     update cj_tas_cortes 
     set fec_hor_corte = sysdate,
         usu_modificacion = USER, 
         fec_modificacion = sysdate
       where nro_caja = to_number(paw_bce.v_nro_terminal);
     IF SQL%NOTFOUND THEN
        insert into cj_tas_cortes(nro_caja, fec_hor_corte, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
        values (to_number(paw_bce.v_nro_terminal), sysdate, USER, sysdate, USER, sysdate);
     END IF;       
exception
   when others then
      raise_application_error(-20000, 'Error en PR_ACT_CORTE. ' || sqlerrm);
end;

-- procedimientos de control de datos recibidos
procedure pr_val_caja  is
-- Verifico la situacion del numero de caja
v_est_caja varchar2(1);
Begin
   Select estado, tipo, cod_oficina, cod_usuario, fec_hor_cierre
     into v_est_caja, v_tip_caja, v_cod_ofi_origen, v_cod_usuario, v_ult_cierre
     from cj_cajas
     where nro_caja = to_number(paw_bce.v_nro_terminal);
   -- BSEVOCORE-583 manejo de v_ult_corte
   Begin
     Select fec_hor_corte
     into v_ult_corte
       from cj_tas_cortes
       where nro_caja = to_number(paw_bce.v_nro_terminal);
   exception
   when no_data_found then
     v_ult_corte := v_ult_cierre;
   end; 
   if v_tip_caja not in ('C','I','S') then
      -- tipo de caja no permitido
      paw_bce.v_cod_respuesta := '-20';
   end if;
   if v_est_caja <> 'A' then
      paw_bce.v_cod_respuesta := '-20';
   end if;
exception
   when no_data_found then
     paw_bce.v_cod_respuesta := '-20'; -- con error
end;

-- valido la cuenta de debito
procedure pr_val_cta_debito
  (p_nro_cta_debito in varchar2,
   p_cod_tra_padre  in number,
   p_monto          in number,
   p_cod_mon_debito out varchar2,
   p_cod_mod_debito out number,
   p_cod_mad_debito out number,
   p_cod_ofi_debito out number,
   p_cta_for_debito out varchar2,
   p_nom_cta_debito out varchar2)
 is
v_est_cta_debito varchar2(1);
v_nvo_estado     varchar2(1) := null; -- cambio de estado de cuenta
v_procesa        varchar2(1) := 'N';
v_sal_disponible number(18,2);
v_can_conjunta   number(7);

-- verifico cuenta de debito
begin
    select a.cod_moneda, a.estado, cod_modalidad,
           cod_modulo, cod_oficina,
           fug_cta_formateada(cod_modulo, cod_modalidad, cod_oficina,nro_cuenta, cod_moneda) cta_formateada,
           denominacion
      into p_cod_mon_debito,
           v_est_cta_debito, p_cod_mad_debito,
           p_cod_mod_debito, p_cod_ofi_debito,
           p_cta_for_debito, p_nom_cta_debito
      from ge_cuentas a
     where a.nro_cuenta = p_nro_cta_debito; -- contiene el nro de cuenta
     -- debito
     if p_cod_mad_debito not in (31,41) then
        v_cod_respuesta := paw_bce.v_cod_cta_invalida;
     elsif v_est_cta_debito not in ('P','I','N','S') then
        v_cod_respuesta := paw_bce.v_cod_cta_invalida;
     elsif pag_cta.fu_ver_tra_prohibida(p_nro_cta_debito,p_cod_tra_padre, 9, 91) = 'S' then
        v_cod_respuesta := paw_bce.v_cod_tra_prohibida;
     elsif fu_es_conjunta(p_nro_cta_debito) = 'S' then
        v_cod_respuesta := paw_bce.v_cod_tra_invalida;
--     elsif p_cod_mad_debito = 31 and pag_cta.fu_obt_cta_cte_comb(p_nro_cta_debito) is not null then
--        v_cod_respuesta := paw_bce.v_cod_cta_invalida;
-- RAMG: Se anulo el control a pedido de L.Kublik el 05/04/2010
     else
        pag_cta.pr_ver_operacion(p_nro_cta_debito,p_cod_tra_padre,9,91,'D',p_cod_mon_debito, p_monto, v_cod_ofi_origen,
                                 p_cod_mod_debito, p_cod_mad_debito, v_nvo_estado, v_sal_disponible,
                                 v_procesa,503);
        if v_procesa = 'N' then
           -- no se puede debitar
           if instr(upper(pag_cta.G_MSJ_ERROR),'INSUFIC') > 0 then
              -- saldo insuficiente
              v_cod_respuesta := paw_bce.v_cod_sal_insuficiente;
           else
              v_cod_respuesta := paw_bce.v_cod_cta_invalida;
           end if;
        end if;
     end if;
     -- agregado para permitir a cuentas indistintas de personas fisicas grabar sin autorizacion
     if v_cod_respuesta = paw_bce.v_cod_aprobado and v_cod_per_empresa is null then
        -- veo si la cuenta no es conjunta
        select count(*) into v_can_conjunta
          from ge_cta_clientes
         where nro_cuenta = p_nro_cta_debito
           and relacion = 'Y'
           and rownum = 1;
        if nvl(v_can_conjunta,0) = 0 then
           -- veo si es persona fisica no debe requerir autorizacion
           v_can_aut_requeridas := 0; -- no tiene autorizacion pendiente cuando es la persona fisica
        end if;
     end if;
exception
    when no_data_found then
       v_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
    when too_many_rows then
       v_cod_respuesta  := paw_bce.v_cod_cta_duplicada;
    when others then
       v_cod_respuesta  := paw_bce.v_cod_cta_invalida;
end;

-- función que valida que una clave (de acceso o transaccional) no se repita,
-- si un usuario posee varias claves, todas deben ser diferentes, p_cla_nueva esta en MD5
-- S : la clave es valida para usar, N : caso contrario
function fu_val_vul_claves(p_cod_persona in bw_ope_claves.cod_persona%type,
                           p_cla_nueva   in bw_ope_claves.clave%type) return varchar2 is
v_cla_valida      varchar2(1) := 'S'; -- es válida la clave
v_clave           varchar2(300);
v_nro_doc_cliente ba_personas.nro_documento%type;
-- obtiene todas las claves que posee la persona
cursor c_claves is
  select cla_verificador, clave, cod_per_vinculada
    from bw_ope_claves
   where cod_persona = p_cod_persona;
begin
  -- buscamos si ya existe la clave nueva creada
  for cla in c_claves loop
    v_clave := cla.cla_verificador || '|' || p_cla_nueva;
    v_clave := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave)));
    if v_clave = cla.clave then
      v_cla_valida := 'N'; -- no es válida la clave
      exit;
    end if;    
    -- buscamos si escogió la clave igual a su cod. persona vinculada
    if v_cla_valida = 'S' and cla.cod_per_vinculada is not null then
     -- v_clave := lower(rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => cla.cod_per_vinculada)))); --BWP-471 - glopez- Se comenta
     /*
        BWP-471 - glopez - Le agregue primero para que encripte en sha1 
     */
       v_clave := paw_bce.fu_enc_md5(paw_bce.fu_enc_sha1(cla.cod_per_vinculada));
      if v_clave = p_cla_nueva then
        v_cla_valida := 'N';
        exit;
      end if;
    end if;
  end loop;
  -- buscamos si escogió la clave igual a su cod. persona
  if v_cla_valida = 'S' then
    --v_clave := lower(rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => p_cod_persona))));--BWP-471 - glopez- Se comenta
    /*
      BWP-471 - glopez - Le agregue primero para que encripte en sha1 
    */
    v_clave := paw_bce.fu_enc_md5(paw_bce.fu_enc_sha1(p_cod_persona));
    if v_clave = p_cla_nueva then
      v_cla_valida := 'N';
    end if;
  end if;
  
  -- buscamos si escogió la clave igual a su CI
  if v_cla_valida = 'S' then
    begin
      select a.nro_documento
        into v_nro_doc_cliente
        from ba_personas a
       where a.cod_persona = p_cod_persona;
      
      --v_clave := lower(rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_nro_doc_cliente))));--BWP-471 - glopez- Se comenta
      /*
        BWP-471 - glopez - Le agregue primero para que encripte en sha1 
      */
      v_clave := paw_bce.fu_enc_md5(paw_bce.fu_enc_sha1(v_nro_doc_cliente));
      if v_clave = p_cla_nueva then
        v_cla_valida := 'N';
      end if;      
    exception
      when others then
        v_cla_valida := 'N';
    end;
  end if;
  -- se agrega validacion nueva para que la clave no contenga fec. de nacimiento ni telefonos
  if v_cla_valida = 'S' and paw_seg.fu_val_gen_clave(p_cod_persona, p_cla_nueva) <> 0 then
     v_cla_valida := 'N';
  end if;
  return v_cla_valida;
end;

/*
    BWP-471 - glopez 
  */
function fu_val_vul_cla(p_cod_persona in bw_ope_claves.cod_persona%type,
                        p_cla_nueva   in bw_ope_claves.clave%type)
return number is
v_cla_valida      varchar2(1) := 'S'; -- es válida la clave
v_clave           varchar2(300);
v_nro_doc_cliente ba_personas.nro_documento%type;
-- obtiene todas las claves que posee la persona
cursor c_claves is
  select cla_verificador, clave, cod_per_vinculada
    from bw_ope_claves
   where cod_persona = p_cod_persona;
begin
  -- buscamos si ya existe la clave nueva creada
  for cla in c_claves loop
    v_clave := cla.cla_verificador || '|' || p_cla_nueva;
    v_clave := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave)));
    if v_clave = cla.clave then
      v_cla_valida := 'N'; -- no es válida la clave
      return -20;
      exit;
    end if;
    -- buscamos si escogió la clave igual a su cod. persona vinculada
    if v_cla_valida = 'S' and cla.cod_per_vinculada is not null then
     -- v_clave := lower(rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => cla.cod_per_vinculada)))); --BWP-471 - glopez- Se comenta
     /*
        BWP-471 - glopez - Le agregue primero para que encripte en sha1 
     */
       v_clave := paw_bce.fu_enc_md5(paw_bce.fu_enc_sha1(cla.cod_per_vinculada));
      if v_clave = p_cla_nueva then
        v_cla_valida := 'N';
         return -21;
        exit;
      end if;
    end if;
  end loop;
  -- buscamos si escogió la clave igual a su cod. persona
  if v_cla_valida = 'S' then
    --v_clave := lower(rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => p_cod_persona))));--BWP-471 - glopez- Se comenta
    /*
      BWP-471 - glopez - Le agregue primero para que encripte en sha1 
    */
    v_clave := paw_bce.fu_enc_md5(paw_bce.fu_enc_sha1(p_cod_persona));
    if v_clave = p_cla_nueva then
      v_cla_valida := 'N';
      return -22;
    end if;
  end if;

  -- buscamos si escogió la clave igual a su CI
  if v_cla_valida = 'S' then
    begin
      select a.nro_documento
        into v_nro_doc_cliente
        from ba_personas a
       where a.cod_persona = p_cod_persona;
     
      --v_clave := lower(rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_nro_doc_cliente))));--BWP-471 - glopez- Se comenta
      /*
        BWP-471 - glopez - Le agregue primero para que encripte en sha1 
      */
      v_clave := paw_bce.fu_enc_md5(paw_bce.fu_enc_sha1(v_nro_doc_cliente));
      if v_clave = p_cla_nueva then
        v_cla_valida := 'N';
        return -23;
      end if;
    exception
      when others then
        return -24;
    end;
  end if;
 
  return paw_seg.fu_val_gen_clave(p_cod_persona, p_cla_nueva);
end;

-- obtener cotizacion para operaciones via banca electronica
function fu_obt_cotizacion
 (p_cod_moneda in ba_monedas.cod_moneda%type
 ,p_tipo       in varchar2  -- C-COMPRA o V-VENTA
 )
 return number
 is

v_cotizacion ge_cotizaciones.val_conversion%type;
begin
   select decode(p_tipo,'C',val_com_electronica,'V',val_ven_electronica,null)
     into  v_cotizacion
     from  ge_cotizaciones a
     where  fecha  = (select max(fecha)
                        from ge_cotizaciones
                       where cod_moneda = a.cod_moneda
                         and fecha <= v_fec_actual)
      and  cod_moneda = p_cod_moneda;
   return v_cotizacion;
exception
   when no_data_found then
      return null;
   when others then
      raise_application_error(-20000,sqlerrm||'error. al buscar cotizacion de venta ');
end;

   --
function fu_act_est_clave(p_cod_persona       bw_ope_claves.cod_persona%TYPE,
                          p_cod_per_vinculada bw_ope_claves.cod_per_vinculada%TYPE,
                          p_tipo              varchar2,
                          p_est_clave         bw_ope_claves.est_clave%TYPE) 
return boolean IS
v_actualizo  boolean;
v_fec_actual date := pag_cal.fu_obt_fec_actual(1);
--p_tipo Tipo Clave. Valores: (T/Transaccional, A/Acceso)
begin
   -- actualizar el valor del estado de la clave a IMPRESA.
   begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
   end;
   
   v_actualizo := true;
    
   if p_tipo in ('A', 'T') then -- si el tipo de clave es acceso o transaccional
      
      if p_est_clave = 'A' then
         insert into bw_cla_acciones(usu_insercion, cod_persona, cod_per_vinculada, accion, tip_clave) 
         values (user, p_cod_persona, p_cod_per_vinculada, 'A', p_tipo/*'T'*/);
      end if;
      
      -- Se le llama desde el report GLCLAOPE para tip_clave = 'T'
      -- Se le llama desde el report GLCLAVE  para tip_clave = 'A'
      update bw_ope_claves
         set est_clave         = nvl(p_est_clave, 'I'),
             fec_est_clave     = v_fec_actual,
             cla_impresa       = null,
             usu_impresion     = user,
             fec_impresion     = v_fec_actual,
             cod_ofi_impresion = fug_obt_ofi_usuario(user)
       where cod_persona       = p_cod_persona
         and (
              (p_cod_per_vinculada is null and cod_per_vinculada is null) or
              (p_cod_per_vinculada is not null and cod_per_vinculada = p_cod_per_vinculada)
             )
         and tip_clave = p_tipo;
          
      if SQL%NOTFOUND then
         v_actualizo := false;
      end if;      
   else
      v_actualizo := false;
   end if;
   
   if v_actualizo then
      commit;
   else
      rollback;
   end if;
   
   return(v_actualizo);
exception
   when others then
      raise_application_error(-20000, 'Error en FU_ACT_EST_CLAVE. ' || sqlerrm);
end;
--
/* convertir un monto de una moneda a otra */
procedure lp_con_mon_a_moneda
 (p_cod_mon_original in ba_monedas.cod_moneda%type
 ,p_cod_mon_destino in ba_monedas.cod_moneda%type
 ,p_mto_mon_original in number
 ,p_mto_mon_destino out number
 ,p_cot_mon_original in out number
 ,p_cot_mon_destino in out number
 ,p_interbancaria in varchar2 default null
 )
 is
   v_lugar           varchar2(100);
begin
    v_lugar := 'obtener moneda base';
    if p_cod_mon_original = p_cod_mon_destino  then
        p_mto_mon_destino := p_mto_mon_original;
        if p_cod_mon_original <> v_cod_mon_local then
           p_cot_mon_destino := nvl(p_cot_mon_original,pag_gen.fu_obt_cotizacion(p_cod_mon_original));
           p_cot_mon_original := p_cot_mon_destino;
        else
           p_cot_mon_destino := 1;
           p_cot_mon_original := 1;
        end if;
   else
      if nvl(p_interbancaria,'N') = 'N' then
       if  p_cod_mon_original <> v_cod_mon_local and p_cod_mon_destino = v_cod_mon_local then
           --convertir moneda original a base o destino
           p_cot_mon_original := nvl(p_cot_mon_original,fu_obt_cotizacion(p_cod_mon_original,'C'/*COMPRA*/));
           p_cot_mon_destino := 1;
           p_mto_mon_destino := round(p_mto_mon_original * p_cot_mon_original,0);
       elsif p_cod_mon_original = v_cod_mon_local and p_cod_mon_destino <> v_cod_mon_local then
           -- pasar moneda original a moneda base
           p_cot_mon_original := 1;
           p_cot_mon_destino := nvl(p_cot_mon_destino,fu_obt_cotizacion(p_cod_mon_destino,'V'/*VENTA */));
           p_mto_mon_destino := round(p_mto_mon_original/p_cot_mon_destino,2);
       elsif p_cod_mon_original <> v_cod_mon_local and p_cod_mon_destino <> v_cod_mon_local then
           p_cot_mon_original := nvl(p_cot_mon_original,fu_obt_cotizacion(p_cod_mon_original,'C'/*COMPRA*/));
           p_mto_mon_destino := p_mto_mon_original * p_cot_mon_original;
           p_cot_mon_destino := nvl(p_cot_mon_destino,fu_obt_cotizacion(p_cod_mon_destino,'V'/*VENTA */));
           p_mto_mon_destino := round(p_mto_mon_destino/p_cot_mon_destino,2);
       end if;
      else --SNP
         if  p_cod_mon_original <> v_cod_mon_local and p_cod_mon_destino = v_cod_mon_local then
             --convertir moneda original a base o destino
             p_cot_mon_original := nvl(p_cot_mon_original,fu_obt_cotizacion(p_cod_mon_original,'V'/*VENTA*/));
             p_cot_mon_destino := 1;
             p_mto_mon_destino := round(p_mto_mon_original * p_cot_mon_original,0);
         elsif p_cod_mon_original = v_cod_mon_local and p_cod_mon_destino <> v_cod_mon_local then
              -- pasar moneda original a moneda base
             p_cot_mon_original := 1;
             p_cot_mon_destino := nvl(p_cot_mon_destino,fu_obt_cotizacion(p_cod_mon_destino,'C'/*COMPRA*/));
             p_mto_mon_destino := round(p_mto_mon_original/p_cot_mon_destino,2);
         elsif p_cod_mon_original <> v_cod_mon_local and p_cod_mon_destino <> v_cod_mon_local then
             p_cot_mon_original := nvl(p_cot_mon_original,fu_obt_cotizacion(p_cod_mon_original,'V'/*VENTA*/));
             p_mto_mon_destino := p_mto_mon_original * p_cot_mon_original;
             p_cot_mon_destino := nvl(p_cot_mon_destino,fu_obt_cotizacion(p_cod_mon_destino,'C'/*COMPRA*/));
             p_mto_mon_destino := round(p_mto_mon_destino/p_cot_mon_destino,2);
         end if;      
      --SNP
      end if;
   end if;
            
   exception
   when others then
      raise_application_error(-20000,v_lugar || ' - ' ||sqlerrm);
end;

-- procedimiento que valida una dirección ip
procedure pr_val_dir_ip(p_ip in ge_par_dinamicos.val_parametro%type) is
v_ip           ge_par_dinamicos.val_parametro%type;
v_error        boolean := false;
v_longitud     integer;
v_posicion     integer := 0;
v_pos_anterior integer := 1;
v_max_longitud integer := 15;
v_max_lon_num  integer := 3;
v_can_min_sep  integer := 3;
v_sep_contador integer := 0;
v_number       number(3);
begin
  v_ip := trim(p_ip);
  v_longitud := length(v_ip);
  
  if v_longitud > v_max_longitud or v_longitud < 7 then
    v_error := true;
  end if;
  -- se valida el formato ip
  begin  
    loop
      v_posicion := instr(v_ip,'.',v_pos_anterior);
      -- se busca si no es el fin
      if (v_posicion - v_pos_anterior) > v_max_lon_num then
        v_error := true;
      end if;
      exit when v_posicion = 0 or v_error;
      -- aumenta el contador de separador '.'
      v_sep_contador := v_sep_contador + 1;
      -- se valida el número
      v_number := to_number(substr(v_ip, v_pos_anterior, v_posicion - v_pos_anterior));
      if v_number > 255 then
        v_error := true;
      end if;
      v_pos_anterior := v_posicion + 1;
    end loop;
    -- se obtiene la última parte
    v_number := to_number(substr(v_ip, v_pos_anterior));
    if v_number > 255 then
      v_error := true;
    end if;
    v_pos_anterior := v_posicion + 1;
  exception 
    when others then
      v_error := true;
  end;
  -- se controla que esten todos los separadores
  if v_sep_contador < v_can_min_sep then
    v_error := true;
  end if;
  
  if v_error then
    raise_application_error(-20000, 'Formato IP inválido. Debe ser en formato #.#.#.#, donde # es un valor numérico entre 0 y 255.');
  end if;
end;

-- procedimiento que valida un puerto tcp, Ojo, al utilizar puertos nuevos
procedure pr_val_puerto(p_puerto in ge_par_dinamicos.val_parametro%type) is
v_puerto number(5);
v_error boolean := false;
v_msj_error varchar2(100);
begin
  begin
    v_puerto := to_number(trim(p_puerto));
    if v_puerto < 1025 or v_puerto > 65535 then
      v_error := true;
      v_msj_error :='Puerto inválido, favor escoja un valor entre 1025 y 65535.';
    elsif v_puerto in (6170, 6175, 6180, 4455, 4446, 4450, 1521) then
      v_error := true;
      v_msj_error :='Puerto reservado, favor escoja otro.';
    end if;
  exception 
    when others then
      v_error := true;
      v_msj_error :='Puerto inválido, debe contener solo números';
  end;
  
  if v_error then
    raise_application_error(-20000, v_msj_error);
  end if;
end;

function fu_val_pin_temporal(p_cod_cliente in varchar2)
return varchar2 is
v_fec_hora  bw_movimientos.fec_hora%type;
v_existe    varchar2(01) := 'N';
begin
   -- Verifico si posee movimientos de creación de pin temporales de IVR
   Begin
     select nvl(max(a.fec_hora),'')
         into v_fec_hora
       from bw_movimientos a
      where a.cod_per_ingreso = p_cod_cliente
        and trunc(a.fec_hora) = v_fec_actual
        and a.cod_tip_mensaje = '080'
        and a.etiqueta = 'Call Center';
   Exception
      When others then
       v_existe := 'N';
   End;
   if v_fec_hora is not null then
      if ((sysdate - v_fec_hora)*24*60) <= 30 then
         v_existe := 'S';
      end if;
   end if;
   RETURN(V_EXISTE);
end;

-- valida que la caja sea homebanking
function fu_caj_homebanking(p_nro_terminal in varchar2)
  return varchar2 is
  v_sino varchar2(1) := 'N';
begin
  if p_nro_terminal in ('999', '994', '888', '991', '990','998') then -- 07/2018
    v_sino := 'S';
  end if;
  return v_sino;
end; 

-- Identificacion del cliente. Devuelve datos del cliente
procedure pr_val_clave(p_parametros in varchar2) is
-- variables
v_can_intentos    number(4) := 0; -- cantidad de intentos fallidos
v_est_clave       varchar2(1);    -- estado de la clave: N-Nueva, A-Activa- B-bloqueada I_Inactiva
v_tip_clave       varchar2(1);    -- Tipo de clave
v_tip_consulta    varchar2(3) := substr(p_parametros,66,3); --Si 010(Validacion cta) o 011(consulta de cta) debe tener
v_dir_correo      varchar2(300);
v_tip_persona     varchar2(1);
v_nro_doc_empresa varchar2(15);
v_tip_doc_empresa varchar2(1);
v_pos             number;
v_nro_documento   number(15) := 0;
begin
  -- 1. Asigno como valido al inicio
  v_cod_respuesta := paw_bce.v_cod_aprobado;
  -- 2. Desarmo los datos recibidos en parametros
  p_clave    := trim(substr(p_parametros,1,32));           -- clave del cliente
  p_dato     := trim(substr(p_parametros,33,16));    -- Dato: nro de documento, cliente o cuenta
  p_dato     := replace(replace(replace(trim(p_dato),'.','-'),' ','-'),'/','-');
  p_tip_dato := nvl(trim(substr(p_parametros,49,1)),'C');  -- Tipo: D-Nro.Doc, C-Cuenta, K-Cod.clientea
  v_nro_doc_empresa  := trim(substr(p_parametros,50,15)); -- empresa si es una empresa la conectada
  v_tip_doc_empresa := substr(p_parametros,65,1); -- tipo de documento de la empresa
  if p_tip_dato = 'C' and (instr(p_dato,'-') > 0 or instr(p_dato,' ') > 0) then
     -- se extrae los guiones de la cuenta
     If v_cod_operacion = '031' or (v_cod_operacion = '010' and v_tip_consulta = '031') then
        -- Si es pago de prestamos solo debe quitarle el guion y el espacio si tiene
        p_dato := trim(replace(p_dato, '-',''));
     Else
        v_pos  := instr(p_dato,'-',-1);
        if v_pos > 0  then
           p_dato := to_number(substr(p_dato,v_pos+1));
        end if;

     End if;
  elsif length(p_dato) = 16 then
     -- es un tarjeta de credito, busco y reemplazo el dato
     declare
       v_nro_cta_tar varchar2(16);
     begin
        select b.nro_cuenta
          into v_nro_cta_tar
          from ta_tarjetas b
         where b.nro_tarjeta = trim(p_dato)
           and rownum = 1;
        -- cambio el nro_de_cuenta por
        p_dato := v_nro_cta_tar;
     exception
       when no_data_found then
          null;
     end;
  end if;
  -- 3. valido los datos del cliente y su clave
  begin
  if p_tip_dato in ('D') then -- nro de documento
      select a.clave, b.nom_completo,  a.cod_usu_oficial, b.cod_persona, a.can_intentos,
             nvl(a.tip_clave,'C'), dir_correo, cod_perfil, b.tipo
        into v_clave, v_nom_completo,  v_cod_usu_oficial, v_cod_persona, v_can_intentos,
             v_tip_clave, v_dir_correo, v_cod_perfil, v_tip_persona
        from  ge_clientes a, ba_personas b
       where a.cod_persona = b.cod_persona
         and b.nro_documento = p_dato;
  --Se solicito que el usuario ya no pueda ingresar por codigo de persona
  elsif p_tip_dato in ('K') and v_cod_operacion <>'005' then -- codigo de cliente
      select a.clave, b.nom_completo,  a.cod_usu_oficial, b.cod_persona, a.can_intentos,
             nvl(a.tip_clave,'C'), dir_correo, cod_perfil, b.tipo
        into v_clave, v_nom_completo,  v_cod_usu_oficial, v_cod_persona, v_can_intentos,
             v_tip_clave, v_dir_correo, v_cod_perfil, v_tip_persona
        from  ge_clientes a, ba_personas b
       where a.cod_persona = b.cod_persona
         and b.cod_persona = p_dato;
  elsif p_tip_dato = 'C' then -- por cuenta
      if v_cod_operacion in ('010','015','031','032') and p_clave = 'a010yzp89c' then
          -- es clave fija
          select a.clave, b.nom_completo,  a.cod_usu_oficial, b.cod_persona, a.can_intentos,
                 nvl(a.tip_clave,'C'), dir_correo, cod_perfil, b.tipo
            into v_clave, v_nom_completo, v_cod_usu_oficial, v_cod_persona, v_can_intentos,
                 v_tip_clave, v_dir_correo, v_cod_perfil, v_tip_persona
            from  ge_clientes a, ba_personas b
           where a.cod_persona = b.cod_persona
             and b.cod_persona in (select x.cod_persona
                           from ge_cta_clientes x
                          where x.nro_cuenta = p_dato
                            and x.cod_persona = b.cod_persona
                            and x.relacion = 'P');
      else
          select tipo, a.cod_persona, b.nom_completo, b.dir_correo
            into v_tip_persona, v_cod_persona, v_nom_completo, v_dir_correo
            from ba_personas b, ge_cta_clientes a
           where a.nro_cuenta = p_dato
             and a.relacion = 'P'
             and a.cod_persona = b.cod_persona;
          begin
              if v_tip_persona = 'J' then -- empresa
              -- busqueda por clave
                  select a.clave,  a.cod_usu_oficial, a.can_intentos, nvl(a.tip_clave,'C'), cod_perfil
                    into v_clave, v_cod_usu_oficial, v_can_intentos, v_tip_clave, v_cod_perfil
                    from ge_clientes a
                   where a.cod_persona = v_cod_persona;
              else -- la cuenta es de una persona fisica
                 -- OMM 05/11/2010 Modificacion para que no tarde tanto el select
                  Begin
                      select a.clave, b.nom_completo,  a.cod_usu_oficial, b.cod_persona, a.can_intentos,
                             nvl(a.tip_clave,'C'), dir_correo, cod_perfil
                        into v_clave, v_nom_completo,  v_cod_usu_oficial, v_cod_persona, v_can_intentos,
                             v_tip_clave, v_dir_correo, v_cod_perfil
                        from  ge_clientes a, ba_personas b
                       where a.cod_persona = b.cod_persona
                         and b.cod_persona in (select x.cod_persona
                                       from ge_cta_clientes x
                                      where x.nro_cuenta = p_dato
                                        and x.cod_persona = b.cod_persona)
                         and rownum = 1; -- primero que encuentre
                   exception
                      when no_data_found then
                          select a.clave, b.nom_completo,  a.cod_usu_oficial, b.cod_persona, a.can_intentos,
                               nvl(a.tip_clave,'C'), dir_correo, cod_perfil
                          into v_clave, v_nom_completo, v_cod_usu_oficial, v_cod_persona, v_can_intentos,
                               v_tip_clave, v_dir_correo, v_cod_perfil
                          from  ge_clientes a, ba_personas b
                         where a.cod_persona = b.cod_persona
                           and length(a.clave) < 11
                           and b.cod_persona in (select x.cod_persona
                                         from ge_cta_clientes x
                                        where x.nro_cuenta = p_dato
                                          and x.cod_persona = b.cod_persona)
                           and rownum = 1; -- primero que encuentre
                    end;
              end if;
          exception
            when no_data_found then
                v_cod_respuesta := paw_bce.v_cod_pin_invalido;
          end;
      end if;
  else  -- error de tipo de
      v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
  end if;
  exception
     when no_data_found then
        v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
     when too_many_rows then
        v_cod_respuesta := paw_bce.v_cod_pin_inexistente;
  end;
  --Verifico si posee pin temporal de ivr
  if v_nro_terminal = '888' and v_est_clave = 'N' then
     If fu_val_pin_temporal(v_cod_persona) = 'S' Then
        update bw_movimientos bw
           set bw.etiqueta2 = 'Fecha Ingreso',
               bw.dato2     = SYSDATE
         where bw.nro_documento = v_nro_documento;
        --
     Else
        v_cod_respuesta := paw_bce.v_cod_call_center;
     End if;
  end if;
  --

  if v_cod_respuesta = paw_bce.v_cod_aprobado and v_tip_persona = 'J' and fu_caj_homebanking(v_nro_terminal) = 'S' /*v_nro_terminal = '999'*/ then
     -- una persona juridica ya no tiene clave, no puede acceder
     v_cod_respuesta := paw_bce.v_cod_pin_invalido;
  end if;
  
  -- 4. Veo la clave si la clave recibida corresponde a la actual
  if v_cod_respuesta in (paw_bce.v_cod_aprobado, paw_bce.v_cod_pin_invalido) then    
    if v_cod_operacion in ('010','015','031','032') and p_clave = 'a010yzp89c' then
       -- caso especial, es un deposito o pago sin PIN, se toma como valido
       v_cod_respuesta := paw_bce.v_cod_aprobado; 
    else
    --Verifica datos de la empresa
    begin
      if v_tip_doc_empresa in ('D', 'K') and v_nro_doc_empresa is not null then -- nro de documento de la empresa
        select b.nom_completo, a.cod_usu_oficial, b.cod_persona,dir_correo, b.tipo
          into v_nom_empresa, v_cod_usu_oficial, v_cod_per_empresa, v_dir_correo, v_tip_persona
          from  ge_clientes a, ba_personas b
         where a.cod_persona = b.cod_persona
           and ((v_tip_doc_empresa = 'D' and b.nro_documento = v_nro_doc_empresa) or
                (v_tip_doc_empresa = 'K' and b.cod_persona = v_nro_doc_empresa)
                );
      end if;
      if v_tip_persona = 'F' and v_nro_doc_empresa is not null then
         -- no puede ingresar como empresa a una persona fisica
         v_cod_respuesta := paw_bce.v_cod_pin_invalido;
      end if;
      -- veo si tiene relacion la persona fisica con la empresa
      if v_cod_respuesta = paw_bce.v_cod_aprobado then
         declare
            v_fec_ven_vinculo date;
         begin
           if v_cod_per_empresa is not null then
               select fec_vencimiento, cod_perfil
                 into v_fec_ven_vinculo, v_cod_perfil
                 from ba_vinculos
                where cod_persona = v_cod_per_empresa
                  and cod_perfil is not null
                  and cod_per_vinculo = v_cod_persona;
           end if;
           if v_cod_perfil is null and v_cod_per_empresa is not null then
              v_cod_respuesta := paw_bce.v_cod_vin_inexistente;
           elsif v_cod_perfil is null and v_cod_per_empresa is null then
              v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
           elsif v_fec_ven_vinculo < sysdate then
              v_cod_respuesta := paw_bce.v_cod_vin_vencido;
           end if;
         exception
            when no_data_found then
               v_cod_respuesta := paw_bce.v_cod_vin_inexistente;
            when others then
               v_cod_respuesta := paw_bce.v_cod_vin_inexistente;
         end;
      end if;
    exception
      when no_data_found then
         v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
    end;
    -- fin verificacion datos empresa
    /*
      -1 Se encontro varios
      -2 No se encontro
      paw_bce.v_cla_ope_cambiar Cambia clave
      -9 Bloqueado
      -4 No es la clave
      -3 error interno
      BBVADES-2613: Se cambia la lógica del control de la clave de acceso
    */    
     if v_cod_respuesta = paw_bce.v_cod_aprobado then
        v_cod_respuesta:= fu_val_ope_clave(p_clave ,v_cod_persona,v_cod_per_empresa, 'A');
        if v_cod_respuesta <> paw_bce.v_cod_aprobado then
        --Si no está aprobada la verificación hay que traducir los errores
          if v_cod_respuesta=paw_bce.v_cla_ope_intentos then
            v_cod_respuesta := paw_bce.v_cod_pin_bloqueado;
          elsif v_cod_respuesta in (-1, -2, -3, -4)then
            v_cod_respuesta:=paw_bce.v_cod_pin_invalido;
          elsif v_cod_respuesta=paw_bce.v_cla_ope_cambiar then
            v_cam_clave := 'S';            
            if v_cod_operacion not in ('005','080') then
              v_cod_respuesta := paw_bce.v_cam_cla_acceso;
            else
              -- para que pueda ingresar y exija el cambio
              v_cod_respuesta := paw_bce.v_cod_aprobado;
            end if;
          elsif v_cod_respuesta=-9 then   
            v_cod_respuesta := paw_bce.v_cod_pin_invalido;
          elsif v_cod_respuesta=0 then   
            v_cod_respuesta := paw_bce.v_cod_aprobado;              
          end if;
        end if;       
        
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
           -- ahora verifico si el usuario tiene acceso a la opción y en que condición
           v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, v_cod_operacion);
           if v_permiso is null then
              v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
           end if;
        end if;                
     end if;
     end if;
  end if;
end;
--- fin de la validacion de la clave

--Verifica que el cliente sea VIP
--Cristhian Benitez 24/01/2011
function fu_es_vip(p_cod_persona in varchar2)
  return varchar2 is
  v_vip varchar2(1);
begin
  select cli_especial
    into v_vip
    from ge_clientes
   where cod_persona=p_cod_persona;
  return to_char(v_vip);
exception
  when others then
     return 'N';
end;
 --fin de es VIP

function fuw_obt_ult_transacciones(p_num_cuenta in varchar2)
         return varchar2 is
         v_retorno varchar2(650);
         v_fecha varchar2(10);
         v_descripcion varchar2(100);
         v_monto varchar2(18);

CURSOR transa_cur IS
        select * from (
        select to_char(fecha,'dd/mm/yyyy') fecha ,  a.concepto, to_char(monto,'0000000000') monto
        from ge_transacciones b, gv_movimientos a
       where a.FECHA>add_months(sysdate,-6)
         and nro_cuenta = p_num_cuenta
         and estado = 'N'
         and reversado = 'N'
         and monto <> 0
         and cod_tip_movimiento in ('D','C')
         and a.cod_modulo = b.cod_modulo
         and a.cod_modalidad = b.cod_modalidad
         and a.cod_transaccion = b.cod_transaccion
         and b.cod_modulo=3 and b.cod_modalidad=31
         and b.ve_cliente = 'S'
         and not exists (select 0 from ah_retenciones x
                          where x.nro_cuenta = a.nro_cuenta
                            and x.nro_documento = a.nro_documento
                            and x.cod_retencion = a.cod_retencion
                            and x.fec_final = a.fec_fin_retencion
                            and x.liberado = 'N')

       order by a.fec_insercion desc, nro_secuencia desc
       ) where    rownum<=5
       ;
begin
  FOR t IN transa_cur LOOP
            v_fecha        := lf_for_char(t.fecha,10);
            v_monto        := lf_for_char(t.monto,18);
            v_descripcion  := lf_for_char(t.concepto,100);
            v_retorno      := v_retorno ||v_fecha||v_descripcion||v_monto;
    END LOOP;

  return lf_for_char(v_retorno, 640);
end;


--Obtiene informaciones del cliente para usar con el webservice que se integra con el altitude
function fuw_obt_dat_cliente(p_documento in varchar2)
  return varchar2 is
  v_nom_oficial   varchar2(50);  -- nombre del oficial del cliente
  v_tel_oficial   varchar2(10);  -- telefono del oficial
  v_nro_documento varchar2(20);
--  v_nombre        varchar2(120);
  v_fec_nacimiento varchar2(10);
  v_dir_principal varchar2(80);
  v_tel_principal varchar2(10);
  v_num_cuenta      varchar2(20);
  v_lin_cre_tarjeta varchar2(18);
  v_fec_ven_tarjeta varchar2(10);
  v_cod_respuesta    varchar2(10);
  v_vip             varchar2(1);
  v_cod_persona     varchar2(10);
  --v_clave           varchar2(32);
  --v_tip_clave       varchar2(2); 
  v_tip_persona     varchar2(2);
  v_cod_modulo      number(3);
  v_num_tarjeta     varchar(20);
  v_cta_pasiva      number(3);
  v_transacciones varchar(640);
  v_est_acceso   varchar(12);
  v_nomina       varchar(60);
begin
  v_cod_respuesta := paw_bce.v_cod_aprobado; --comienza todo bien

  -- 2. obtiene toda la informacion del cliente
  begin
    select /*a.clave,*/ b.nom_completo, a.cod_usu_oficial, a.cli_especial,
            b.cod_persona, /*nvl(a.tip_clave,'C'),*/ b.tipo, ba_direcciones.direccion
      into /*v_clave,*/ v_nom_completo, v_cod_usu_oficial, v_vip,
            v_cod_persona, /*v_tip_clave,*/ v_tip_persona,
            v_dir_principal
      from ge_clientes a, ba_personas b, ba_direcciones
     where replace(b.nro_documento, '-', '') = p_documento
       and a.cod_persona = b.cod_persona
       and ba_direcciones.cod_persona = b.cod_persona
       and  ba_direcciones.principal ='S';
  exception
    when others then
      v_cod_respuesta  := paw_bce.v_cod_otr_error;
      v_nom_completo   := '';
  end;
-- 2.1  Si es persona fisica pregunto por su fecha de nacimiento
  If pag_gen.FU_ES_PER_FISICA(v_cod_persona) = 'S' then
     begin
       select to_char(f.fec_nacimiento,'DD/MM/YYYY')
         into v_fec_nacimiento
         from ba_per_fisicas f
        where f.cod_persona=v_cod_persona;
     exception
       when others then
         null;
     end;
  end if;
--2.2 Puede que no tenga telefono entonces se separa tambien
     begin
       select t.area || t.telefono
            into v_tel_principal
            from ba_telefonos t
            where t.cod_persona=v_cod_persona
            and t.principal='S';
          exception
            when others then
               null;
     end;
  --3. Se obtiene informacion del oficial de cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     begin
        select substr(nvl(u.nombre,' '),1,50),
               substr(nvl(u.telefono,'4176000'),1,10)
          into v_nom_oficial, v_tel_oficial
          from ba_usuarios u
         where cod_usuario = v_cod_usu_oficial;
     exception
        when others then
           v_cod_respuesta  := paw_bce.v_cod_otr_error;
     end;
  end if;
--6. Se obtiene informacion de la cuenta
   if v_cod_respuesta = paw_bce.v_cod_aprobado then
     begin
        select b.nro_cuenta,b.cod_modulo
        into v_num_cuenta,v_cod_modulo
        from
        ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b

        where b.cod_persona=v_cod_persona and
        a.nro_cuenta = b.nro_cuenta
        and b.relacion in ('O', 'P','Y')
        and a.cod_modulo = c.cod_modulo
        and a.cod_modalidad = c.cod_modalidad
        and a.estado = c.estado
        and c.activo = 'S'  -- solo cuentas activas
        and a.estado <> 'X' -- pendiente de verificacion
        and b.cod_modalidad in (31,41)
        and rownum=1;
        v_cta_pasiva:=1;
     exception
        when others then
           v_cta_pasiva:=0; --No tiene cuentas pasivas tiene que tener una tarjeta??
     end;
  end if;
/*
   select a.nro_cuenta, a.cod_modalidad cod_modalidad,
         fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina,a.nro_cuenta, a.cod_moneda) cta_formateada,

         a.cod_moneda cod_moneda, a.denominacion nom_cuenta,
         a.cod_modulo
    from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
   where a.nro_cuenta = b.nro_cuenta
     and b.relacion in ('O', 'P','Y')
     and a.cod_modulo = c.cod_modulo
     and a.cod_modalidad = c.cod_modalidad
     and a.estado = c.estado
     and c.activo = 'S'  -- solo cuentas activas
     and a.estado <> 'X' -- pendiente de verificacion
     and b.cod_modalidad in (31,41)

*/
   --CANREQVAR-610 - HO - Obtenemos el dato: nomina del cliente (Que indique el nombre de la Nómina si lo fuese, caso contrario dirá ENTE NO ASOCIADO).
    begin
      select fue_obt_nom_ente(cod_ente)
        into v_nomina
        from (Select distinct ah.cod_ente
                from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
               where cl.nro_cuenta = ah.nro_cuenta
                 and cl.cod_persona = v_cod_persona
                 and cl.cod_modulo = g.cod_modulo
                 and cl.cod_modalidad = g.cod_modalidad
                 and ah.estado = g.estado
                 and g.activo = 'S'
                 and cl.relacion = 'P'
                 and ah.cod_ente is not null
                 and ah.nro_cuenta = v_num_cuenta
              UNION
              Select distinct cc.cod_ente
                from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
               where cc.nro_cuenta = cl.nro_cuenta
                 and cl.cod_persona = v_cod_persona
                 and cl.cod_modulo = g.cod_modulo
                 and cl.cod_modalidad = g.cod_modalidad
                 and cc.estado = g.estado
                 and g.activo = 'S'
                 and cl.relacion = 'P'
                 and cc.cod_ente is not null
                 and cc.nro_cuenta = v_num_cuenta);
    exception
      when too_many_rows then
        v_nomina := 'MAS DE UN ANTE ASOCIADO';
      when no_data_found then
        v_nomina := 'ENTE NO ASOCIADO';
      when others then
        v_nomina := 'ENTE NO ASOCIADO';
    end;
--5. Se obtiene informacion de la tarjeta de credito si es que tiene
   if v_cod_respuesta = paw_bce.v_cod_aprobado then
     begin
     if(v_cta_pasiva=0) then -- es una tarjeta
      select t.nro_tarjeta,
                 to_char(t.fec_vencimiento,'dd/mm/yyyy'),ct.lin_credito
    into       v_num_tarjeta,
               v_fec_ven_tarjeta,
               v_lin_cre_tarjeta
        from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b,Ta_tarjetas t,ta_cta_tarjetas ct
       where a.nro_cuenta = b.nro_cuenta
         and t.nro_cuenta=a.nro_cuenta
         and ct.nro_cuenta=t.nro_cuenta
         and b.relacion in ('O','P','Y')
         and b.cod_persona = v_cod_persona
         and a.cod_modulo = c.cod_modulo
         and a.cod_modalidad = c.cod_modalidad
         and a.estado = c.estado

         and b.cod_modulo = 5
         and b.cod_modalidad <> 55 --Tarjeta gourmet no se tiene en cuenta
         and c.activo = 'S'  -- solo cuentas activas
         and a.estado not in ('X','T','D','C','V','P','B')  -- pendiente de verificacion
         and rownum=1
         --and (p_cod_moneda is null or a.cod_moneda = p_cod_moneda)
       order by t.fec_activacion desc;
         --si es tarjeta tengo que mostrar el numero de tarjeta como numero de cuenta
               v_num_cuenta:=v_num_tarjeta;
   else --si la cuenta principal no es tarjeta de credito busco alguna tarjeta vigente

      select t.nro_tarjeta,
                     to_char(t.fec_vencimiento,'dd/mm/yyyy'),ct.lin_credito
             into       v_num_tarjeta,
               v_fec_ven_tarjeta,
               v_lin_cre_tarjeta
        from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b,Ta_tarjetas t,ta_cta_tarjetas ct
       where a.nro_cuenta = b.nro_cuenta
         and t.nro_cuenta=a.nro_cuenta
         and ct.nro_cuenta=t.nro_cuenta
         and b.relacion in ('O','P','Y')
         and b.cod_persona = v_cod_persona
         and a.cod_modulo = c.cod_modulo
         and a.cod_modalidad = c.cod_modalidad
         and a.estado = c.estado

         and b.cod_modulo = 5
         and b.cod_modalidad <> 55 --Tarjeta gourmet no se tiene en cuenta
         and c.activo = 'S'  -- solo cuentas activas
         and a.estado not in ('X','T','D','C','V','P','B')  -- pendiente de verificacion
         and rownum=1
         --and (p_cod_moneda is null or a.cod_moneda = p_cod_moneda)
       order by t.fec_activacion desc;
     end if;

     exception
        when no_data_found then --no tiene tarjetas de credito
           null;
     end;
  end if;
--6. Obtengo las ultimas transacciones
     if(v_cta_pasiva=1) then
         v_transacciones := fuw_obt_ult_transacciones(v_num_cuenta);
      else
        v_transacciones := lf_for_char('',640);
      end if;

    --CANREQVAR-610 - HO - Obtenemos el dato: estado de la clave de acceso
    begin
      select b.significado
        into v_est_acceso
        from bw_ope_claves a, ba_cod_referencias b
       where a.tip_clave = 'A'
         and b.dominio = 'EST_CLAVE'
         and a.est_clave = b.val_minimo
         and a.cod_per_vinculada is null
         and a.cod_persona = v_cod_persona;
    exception
      when others then
        v_est_acceso := 'Sin Clave';
    end;

   return --lf_for_char(p_documento,100)||
--   lf_for_char(v_nom_oficial,50)||
--   lf_for_char(v_tel_oficial,10)||
      lf_for_char(v_num_tarjeta,20)||
      lf_for_char(v_nom_completo,120)||
      lf_for_char(v_fec_nacimiento,10)||
      lf_for_char(v_dir_principal,80)  ||
      lf_for_char(v_tel_principal,10)  ||
      lf_for_char(v_lin_cre_tarjeta,18)||
      lf_for_char(v_num_cuenta,20)||
      lf_for_char(v_fec_ven_tarjeta,10)||
      lf_for_char(v_vip,1)||
      lf_for_char(v_cod_respuesta,5)||
      v_transacciones||
      lf_for_char(v_est_acceso,12)||
      lf_for_char(v_nomina,60);

end;--fin de informaciones para el altitude

--Verifica si existe el movimiento en el historico para la fecha.
procedure lp_can_reg_historicos(p_nro_cuenta in ge_cuentas.nro_cuenta%type,
                                p_fecha      in ge_movimientos.fecha%type,
                                p_horario    out varchar2) is
  v_lugar         varchar2(100);
  v_can_registros number(5) := 99;
begin
  v_lugar := 'obtener cantidad de registros historicos';
  begin
    select 1
      into v_can_registros
      from cc_movimientos_his h
     where h.fecha      = p_fecha
       and h.nro_cuenta = p_nro_cuenta
       and rownum       = 1
    union
    select 1
      from ah_movimientos_his h
     where h.fecha      = p_fecha
       and h.nro_cuenta = p_nro_cuenta
       and rownum       = 1;
  exception
    when no_data_found then
      v_can_registros := 0;
  end;
  if v_can_registros = 0 then
    p_horario := 'D';
  end if;
exception
  when others then
    raise_application_error(-20000, v_lugar || ' - ' || sqlerrm);
end;
  
  --Guarda una accion con las claves de operaciones
procedure lp_cla_reg_operacion(p_cod_persona in varchar2, p_accion in varchar2,p_cod_per_vinculada in varchar2, p_tip_clave in varchar2) is
  PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
  begin
   insert into BW_CLA_ACCIONES
      (cod_persona,accion,tip_clave,cod_per_vinculada)
    values
      (p_cod_persona,p_accion,p_tip_clave,p_cod_per_vinculada);--Codigo C es para Crear -- R Cambiar
    commit;
  exception
   when others then
      raise_application_error(-20000,sqlerrm);
end;

--Verifica que la clave transaccional sea la correcta
--hace un substr desde p_ini_ope_clave-1 hasta p_ini_ope_clave+31
function lf_obt_cla_validar(p_parametro in varchar2,p_cod_persona in varchar2,p_cod_per_vinculada in varchar2,p_ini_ope_clave in number, p_tip_clave in varchar2)
return varchar2 is
  v_md5_clave varchar2(32);
  v_cla_valida number;
begin
  v_md5_clave   :=SUBSTR(p_parametro,p_ini_ope_clave,32);
  v_cla_valida  :=FU_VAL_OPE_CLAVE (v_md5_clave , p_cod_persona , p_cod_per_vinculada, p_tip_clave);

  if(v_cla_valida=0) then
    return paw_bce.v_cod_aprobado;
  elsif (v_cla_valida=-9) then
       return paw_bce.v_cla_ope_estado;
  elsif(v_cla_valida=paw_bce.v_cla_ope_intentos) then
       return paw_bce.v_cla_ope_intentos;
  elsif v_cla_valida=paw_bce.v_cla_ope_cambiar then
    return paw_bce.v_cla_ope_cambiar;
  end if;
  
  return paw_bce.v_cla_ope_invalida;
end;

-- Verifica que el token especificado sea el correcto
function fu_obt_tok_validar(p_parametro         in varchar2,
                            p_cod_persona       in ba_personas.cod_persona%type,
                            p_cod_per_vinculada in ba_personas.cod_persona%type,
                            p_ini_cla_otp       in number,
                            p_modo              in varchar2)
  return varchar2 is
v_cla_otp      varchar2(15);
v_usuario      varchar2(30);
v_dominio      varchar2(30); 
v_password     varchar2(20);
v_otp_servidor varchar2(20);
v_otp_puerto   number(5);
v_tie_espera   number;
v_tip_pedido   varchar2(1);
v_pedido       varchar2(96);
v_enviar       varchar2(1) := 'S';
v_ok           varchar2(1);
v_respuesta    varchar2(2000);
v_cod_mensaje  varchar2(3) := paw_bce.v_cod_respuesta;
v_tipo         bw_otp_seriales.tipo%type;
v_cod_ente     ge_entes.cod_ente%type;

begin
  if p_cod_per_vinculada is null then
    v_usuario := p_cod_persona;
    v_dominio := nvl(fug_obt_pardinamico('OTP_DOM_FISICA'), 'PERSONA_FISICA'); -- evaluar usar parametro dinamico    
  else
    v_usuario := p_cod_per_vinculada||'_'||p_cod_persona;
    v_dominio := nvl(fug_obt_pardinamico('OTP_DOM_JURIDICA'), 'PERSONA_JURIDICA'); -- evaluar usar parametro dinamico
  end if;

  if p_modo = 'V' then
    v_cla_otp := null;
    v_tip_pedido := 'S'; -- pedir a VASCO envío de challenge SMS
    
    begin
      select tipo
        into v_tipo
        from bw_otp_seriales
       where cod_persona = p_cod_persona
         and nvl(cod_per_vinculada, 'x') = nvl(p_cod_per_vinculada, 'x')
         and tipo in ('V','F')
         and estado = 'A';
    exception
      when others then
        v_enviar := 'N';
        v_cod_mensaje := paw_bce.v_cla_otp_inexistente;
    end;
    
    if v_enviar = 'S' and v_tipo <> 'V' then
      v_enviar := 'N'; -- es un token físico, no se envía challenge
    end if;
  else
    v_cla_otp := substr(p_parametro,p_ini_cla_otp, paw_bce.v_max_lon_otp);
    v_tip_pedido := 'V'; -- verificar la clave OTP con VASCO
  end if;
  
  if v_enviar = 'S' then                           
    begin        
      -- obtenemos el ente regulador de clave otp
      v_cod_ente := fug_obt_pardinamico('COD_ENT_SOC_OTP');      
      -- obtenemos los parametros del digipass
      v_otp_servidor := fug_obt_parentes(v_cod_ente, 'IP');
      v_otp_puerto   := fug_obt_parentes(v_cod_ente, 'PUERTO');
      v_tie_espera   := nvl(fug_obt_parentes(v_cod_ente, 'TIMEOUT'), 20);      
      v_password     := substr(trim(fug_obt_parentes(v_cod_ente, 'PASSWORD')), 1, 20);
      -- armamos el mensaje
      v_pedido := v_tip_pedido||lf_for_char(v_usuario, 30)
                              ||lf_for_char(v_dominio, 30)
                              ||lf_for_char(v_password, 20)
                              ||lf_for_char(v_cla_otp, 15);
      -- enviamos el mensaje al servidor de claves otp
      v_ok := fue_env_tcp_mensajes(v_otp_servidor, v_otp_puerto, v_tie_espera, v_pedido, v_respuesta);
      if v_ok = 'S' then
        v_cod_mensaje := substr(v_respuesta, 0, 3);
        if v_cod_mensaje in ('001', '010', paw_bce.v_cod_otr_error) then
          v_cod_mensaje := paw_bce.v_cod_err_con_vasco;
         elsif v_cod_mensaje in (paw_bce.v_tok_invalido) then
          v_cod_mensaje := paw_bce.v_tok_invalido;
         elsif v_cod_mensaje in ('002') then
          v_cod_mensaje := paw_bce.v_cod_tok_ine_vasco;
        elsif v_cod_mensaje not in (paw_bce.v_cod_aprobado) then
          v_cod_mensaje := paw_bce.v_cod_ope_no_permitida;
        end if;
      else
        v_cod_mensaje := paw_bce.v_cod_err_con_socket;
      end if;
    exception 
      when others then
        v_cod_mensaje := paw_bce.v_cod_err_con_socket;
    end;
  end if; 
  
  return v_cod_mensaje;
exception 
  when others then
     return paw_bce.v_tok_invalido;
end;

  --Verifica los ultimos accesos de las claves y actualiza el estado de la misma
  PROCEDURE lp_act_est_ope_clave(p_cod_persona       IN VARCHAR2,
                                 p_cod_per_vinculada IN VARCHAR2,
                                 p_tip_clave         IN VARCHAR2) IS
     PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
     v_ope_cam_cambio NUMBER(5);
     v_ope_cam_uso    NUMBER(5);
  BEGIN
     --Si no exite el parámetro dinámico, toma 90 días
     BEGIN
        IF p_tip_clave = 'T' THEN
           -- frecuencia de cambio para clave transaccional
           v_ope_cam_cambio := TO_NUMBER(fug_obt_pardinamico('OPE_CAM_CAMBIO', 1));
        ELSE
           -- frecuencia de cambio para clave de acceso
           v_ope_cam_cambio := TO_NUMBER(fug_obt_pardinamico('FRE_CAM_CLA_ACCESO_HB'));
        END IF;
     EXCEPTION
        WHEN OTHERS THEN
           v_ope_cam_cambio := 90;
     END;
     -- controlamos el valor de v_ope_cam_cambio
     IF v_ope_cam_cambio IS NULL THEN
        v_ope_cam_cambio := 90;
     END IF;
     -- Si no existe el parámetro dinámico toma 45 días
     BEGIN
        IF p_tip_clave = 'T' THEN
           -- frecuencia de cambio para clave transaccional
           v_ope_cam_uso := TO_NUMBER(fug_obt_pardinamico('OPE_CAM_USO', 1));
        ELSE
           -- frecuencia de cambio para clave de acceso
           v_ope_cam_uso := TO_NUMBER(fug_obt_pardinamico('OPE_CAM_USO_ACCESO'));
        END IF;
     EXCEPTION
        WHEN OTHERS THEN
           v_ope_cam_uso := 45;
     END;
     -- controlamos el valor de v_ope_cam_uso
     IF v_ope_cam_uso IS NULL THEN
        v_ope_cam_uso := 45;
     END IF;
  
     BEGIN
        -- exige el cambio a las claves que no se usaron en un tiempo
        -- segun OPE_CAM_USO(transaccional) o OPE_CAM_USO_ACCESO(acceso) días
        UPDATE bw_ope_claves
           SET est_clave     = 'A', 
               fec_est_clave = SYSDATE
         WHERE cod_persona   = p_cod_persona
           AND tip_clave = p_tip_clave
           AND est_clave NOT IN ('X', 'I', 'B') -- no cambiar si el estado es anulada, impresa o bloqueada
           AND (
                (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR
                (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
               )
           AND (fec_ult_acceso IS NULL OR SYSDATE - fec_ult_acceso > v_ope_cam_uso);
        COMMIT;
     EXCEPTION
        WHEN OTHERS THEN
           NULL;
     END;
  
     BEGIN
        -- Exigir el cambio de clave a los que cambiaron hace 
        -- FRE_CAM_CLA_ACCESO_HB(Acceso) o OPE_CAM_CAMBIO(Transaccional) días
        UPDATE bw_ope_claves
           SET est_clave = 'A', fec_est_clave = SYSDATE
         WHERE cod_persona = p_cod_persona
           AND est_clave = 'M'
           AND ( 
                (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR 
                (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
               )
           AND tip_clave = p_tip_clave
           AND SYSDATE - FEC_CAM_CLAVE > v_ope_cam_cambio;        
        COMMIT;
     EXCEPTION
        WHEN OTHERS THEN
           NULL;
     END;
  END;

--recibe la clave en minusculas y hasheada en md5 recupera el salt del usuario y verifica que la clave sea igual a la guardada
function fu_val_ope_clave(p_clave             in varchar2,
                          p_cod_persona       in varchar2,
                          p_cod_per_vinculada in varchar2,
                          p_tip_clave         in varchar2) 
  return number is
v_salt         number;
v_clave        varchar(300);
v_estado       varchar(1);
v_can_errores  number(2);
v_max_intentos number;
 
  --Verifica que la clave si tiene mas de 3 intentos fallidos pase a estado B
  PROCEDURE lp_blo_clave(p_cod_persona       IN VARCHAR2,
                         p_cod_per_vinculada IN VARCHAR2,
                         p_tip_clave         IN VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transacción
  BEGIN
     UPDATE bw_ope_claves
        SET est_clave     = 'B',
            fec_est_clave = SYSDATE
      WHERE cod_persona = p_cod_persona
        AND est_clave IN ('A', 'M') -- se bloquea solo si esta para cambiar o modificado
        AND can_intentos >= v_max_intentos
        AND (
             (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR 
             (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
            )
        AND tip_clave = p_tip_clave;
     COMMIT;
  EXCEPTION
     WHEN OTHERS THEN
        NULL;
  END;    
  --registra que cuando ocurrio un error en el uso de la clave
  --para validar que no se ingrese mal la clave muy rapido
  PROCEDURE lp_reg_error(p_cod_persona       IN VARCHAR2,
                         p_cod_per_vinculada IN VARCHAR2,
                         p_tip_clave         IN VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transacción
  BEGIN
     UPDATE bw_ope_claves
        SET fec_ult_error = SYSDATE,
            can_intentos = nvl(can_intentos, 0) + 1
      WHERE cod_persona = p_cod_persona
        AND (
             (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR 
             (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
            )
        AND tip_clave = p_tip_clave;
     COMMIT;
     lp_blo_clave(p_cod_persona, p_cod_per_vinculada,p_tip_clave);
  EXCEPTION
     WHEN OTHERS THEN
        NULL;
  END;

  --actualiza el ultimo acceso realizado, en caso de que la clave sea la correcta
  --reinicia el contados de intentos fallidos a 0
  PROCEDURE lp_act_visitas(p_cod_persona       IN VARCHAR2,
                           p_cod_per_vinculada IN VARCHAR2,
                           p_tip_clave         IN VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transacción
  BEGIN
     BEGIN
        UPDATE bw_ope_claves
           SET can_acceso = can_acceso + 1,
               can_intentos = 0,
               fec_ult_acceso = SYSDATE
         WHERE cod_persona = p_cod_persona
           AND (
                (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR 
                (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
               )
           AND tip_clave = p_tip_clave;
     EXCEPTION 
       WHEN OTHERS THEN
          -- por si bw_ope_claves.can_acceso llego a su tope, se reinicia
          UPDATE bw_ope_claves
             SET can_acceso = 0,
                 can_intentos = 0,
                 fec_ult_acceso = SYSDATE
           WHERE cod_persona = p_cod_persona
             AND (
                  (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR 
                  (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
                 )
             AND tip_clave = p_tip_clave;
     END;
     COMMIT;
  EXCEPTION
     WHEN OTHERS THEN
        NULL;
  END;
begin
  BEGIN 
     -- obtiene el salt y el estado
     select cla_verificador, est_clave, can_intentos
       into v_salt, v_estado, v_can_errores
       from bw_ope_claves
      where cod_persona = p_cod_persona
        and (
             (p_cod_per_vinculada is null and cod_per_vinculada is null) or
             (p_cod_per_vinculada is not null and cod_per_vinculada = p_cod_per_vinculada)
            )
        and tip_clave = p_tip_clave;
  EXCEPTION
     WHEN too_many_rows THEN
        return - 1;
     WHEN no_data_found THEN
        lp_reg_error(p_cod_persona, p_cod_per_vinculada,p_tip_clave);
        return - 2;
  END;
  
  lp_act_est_ope_clave(p_cod_persona, p_cod_per_vinculada, p_tip_clave);
  
  v_clave := v_salt || '|' || p_clave;
  v_clave := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave)));
  
  -- obtenemos la máxima cantidad de intentos de uso de claves
  BEGIN 
    if p_tip_clave = 'T' then -- máxima cantidad para clave transaccional
      v_max_intentos := to_number(fug_obt_pardinamico('CAN_INT_CLA_TRANSACCIONAL'));
    else -- máxima cantidad para clave de acceso
      v_max_intentos := to_number(fug_obt_pardinamico('CAN_INT_CLA_ACCESO'));
    end if;
  EXCEPTION 
    WHEN OTHERS THEN
      if p_tip_clave = 'T' then
        v_max_intentos := 3;
      else
        v_max_intentos := 5;
      end if;      
  END;
  -- controlamos el valor de v_max_intentos
  IF v_max_intentos IS NULL THEN
     v_max_intentos := 5;
  END IF;
  -- se verifica la cantidad de intentos fallidos de clave de acceso o transaccional
  if (v_can_errores >= v_max_intentos) then
    lp_reg_error(p_cod_persona, p_cod_per_vinculada,p_tip_clave);
    if v_estado in ('A', 'M', 'B') then
      v_cod_respuesta := paw_bce.v_cla_ope_intentos;
    else
      v_cod_respuesta := -9;
    end if;
    return v_cod_respuesta;
  end if;
      
  BEGIN
     select cla_verificador, est_clave
       into v_salt, v_estado
       from bw_ope_claves
      where cod_persona = p_cod_persona
        and (
             (p_cod_per_vinculada is null and cod_per_vinculada is null) or 
             (p_cod_per_vinculada is not null and cod_per_vinculada = p_cod_per_vinculada)
            )
        and clave = v_clave
        and tip_clave = p_tip_clave;
     --La clave tiene que estar activa
     if v_estado <> 'M' then
        if v_estado = 'A' then
           v_cod_respuesta := paw_bce.v_cla_ope_cambiar;
           return paw_bce.v_cla_ope_cambiar;
        elsif v_estado = 'B' then
           return paw_bce.v_cla_ope_intentos;
        else    
           return -9;
        end if;
     end if;     
  EXCEPTION
     WHEN too_many_rows THEN
        return - 3;
     WHEN no_data_found THEN
        lp_reg_error(p_cod_persona, p_cod_per_vinculada,p_tip_clave);
        v_cod_respuesta:=paw_bce.v_cla_ope_invalida;
        return - 4;        
  END;
  -- actualizar si es de clave transaccional, y si es acceso solo si viene de inicio de sesión
  if (p_tip_clave = 'T' or (p_tip_clave = 'A' and v_cod_operacion = '005')) then
    lp_act_visitas(p_cod_persona, p_cod_per_vinculada,p_tip_clave);
  end if;
  v_cod_respuesta := v_cod_aprobado;
  RETURN 0;
END;
 
--genera una clave lista para guardar en bw_ope_claves, si generar ='S' 
--crea una clave con un numero aleatorio y la retorna en p_cla_operacion
--
--la clave no debe ser almacenada en ningun lugar en plano, siempre tiene que estar al menos hasheada
-- p_cod_per_vinculada tiene que ser nulo si es una persona fisica
function fu_gen_ope_clave (p_clave             in  varchar2, 
                           p_cod_persona       in  varchar2,
                           p_cod_per_vinculada in  varchar2, 
                           p_accion            in  varchar2, 
                           p_tip_clave         in  varchar2, 
                           p_cla_operacion     out varchar2,
                           p_nro_lote          in number default null)
  return varchar2 is
v_salt      NUMBER;
v_clave        VARCHAR2(300);
v_clave_aux NUMBER;
v_tex_email    VARCHAR2(8000);
v_dir_correo   ba_personas.dir_correo%TYPE;
v_pri_nombre   ba_per_fisicas.pri_nombre%TYPE;
v_pri_apellido ba_per_fisicas.pri_apellido%TYPE;
v_empresa      ba_personas.nom_completo%TYPE;
v_ruc          ba_personas.nro_documento%TYPE;
v_inf_json     long := null;
v_asunto_email VARCHAR2(1000);
v_tip_pro_cliente it.ba_env_correos.tip_producto%type;
v_dias         VARCHAR2(4);
v_template     LONG;
 --guarda en el log
BEGIN
  --verifica que la persona este relacionada a la empresa
  IF p_cod_per_vinculada IS NOT NULL THEN
     IF fu_val_per_vinculada(p_cod_per_vinculada, p_cod_persona) = 'N' THEN
        RETURN -5;
     END IF;
  END IF;
   
  v_salt := round(dbms_random.value(1000000, 9999999));
   
  IF (p_clave IS NULL OR p_accion = 'C') THEN
    IF (p_tip_clave='A') then
     v_clave_aux     := round(dbms_random.value(100000000, 999999999));
    ELSE 
     v_clave_aux     := round(dbms_random.value(100000, 999999));
    END IF;
     p_cla_operacion := v_clave_aux;
  ELSIF p_accion <> 'A' THEN -- p_clave ya viene hasheada con p_accion = 'A'
     v_clave_aux := to_number(p_clave);
  END IF;
  --hago el hash 2 veces porque necesito poder enviar desde el hb la clave y que no se pueda ver en los logs
  --se va a enviar la clave hasheada, entonce se vuelve a hashear
  --los hash se guardan en minusculas para que sean iguales a los producidos por perl
  -- BBVADES-2613: modificado para reutilizar desde fu_pro_operacion_080 y fu_pro_operacion_219
  --               donde la clave ya viene hasheada y envia p_accion = 'A'           
  IF p_accion = 'A' THEN
    v_clave := p_clave;
  ELSE
    v_clave := paw_bce.fu_enc_sha1(v_clave_aux);
    v_clave := lower(rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave))));
  END IF;
   
  --aca hasheo el hasheo de la clave
  v_clave := v_salt || '|' || v_clave;
  v_clave := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave)));
   
  --Si acción es N, crear Nueva contraseña
  CASE p_accion
     WHEN 'C' THEN
        BEGIN
           INSERT INTO bw_ope_claves
              (cla_verificador, clave, can_acceso, est_clave, cod_persona, cod_per_vinculada, tip_clave, nro_lote)
           VALUES
              (v_salt, v_clave, 0, /*'N'*/'A', p_cod_persona, p_cod_per_vinculada, p_tip_clave, p_nro_lote);
           lp_cla_reg_operacion(p_cod_persona, p_accion, p_cod_per_vinculada, p_tip_clave);
        EXCEPTION
           WHEN dup_val_on_index THEN
              --Si hay error de PK intenta actualizar
              BEGIN
                 UPDATE bw_ope_claves
                    SET cla_verificador = v_salt,
                        clave           = v_clave,
                        est_clave       = 'A',
                        --est_clave       = 'N',
                        can_intentos    = 0
                  WHERE cod_persona = p_cod_persona
                    AND tip_clave = p_tip_clave
                    AND (
                         (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR 
                         (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
                        );
                 lp_cla_reg_operacion(p_cod_persona, p_accion, p_cod_per_vinculada, p_tip_clave);
              EXCEPTION
                 WHEN OTHERS THEN
                    RETURN - 7;
              END;
           WHEN OTHERS THEN
              RETURN - 1;
        END;

        -- Enviamos por mail la contraseña generada al cliente para Clave de Acceso (A) y Clave Transaccional (T)
       IF p_tip_clave IN ('A', 'T') THEN

           BEGIN
              SELECT p.pri_nombre, p.pri_apellido
                INTO v_pri_nombre, v_pri_apellido
                FROM ba_per_fisicas p
               WHERE p.cod_persona = p_cod_persona;
           EXCEPTION
              WHEN OTHERS THEN
                v_pri_nombre   := NULL;
                v_pri_apellido := NULL;
           END;

           BEGIN
             SELECT t.nom_completo, t.nro_documento
               INTO v_empresa, v_ruc
               FROM ba_personas t
              WHERE t.cod_persona = p_cod_per_vinculada;
           EXCEPTION
              WHEN OTHERS THEN
                v_empresa := NULL;
                v_ruc     := NULL;
           END;

           BEGIN
             /*
              Ticket: BWP-652
              User: GLOPEZ
              Desc.: Buscamos de ba_tab_dat_adicionales
             */
              v_dir_correo := fue_tab_dat_adicional('BA_PERSONAS','EMAIL_ONBOARDING',p_cod_persona);
           EXCEPTION
              WHEN OTHERS THEN
                 v_dir_correo := Null;
           END;

           IF p_tip_clave = 'A' THEN
             v_dias := fug_obt_pardinamico('BWE_DIA_CLA_INHABILITADO');
             v_tip_pro_cliente := fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVCLAVE');--Envio de Clave de Acceso
           ELSE
             if p_cod_per_vinculada is not null then --BWP-303
                v_dias := fug_obt_pardinamico('BWE_DIA_CLA_INH_TRANSACCIONAL');
                v_tip_pro_cliente := fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVCLATRA');--Envio de Clave Transaccional
             else --BWP-303
                v_dias := fug_obt_pardinamico('BWE_DIA_CLA_INH_TRANSACCIONAL'); --BWP-303
                v_tip_pro_cliente := fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVCLATRAP');--Envio de Clave Transaccional --BWP-303
            end if; --BWP-303
           END IF;
           --NVB-380 -- Para que envie por ba_env_correos
           declare
            v_inf_deb_json long :=    null;
            retError         typ_mensajeRespuesta := typ_mensajeRespuesta;
           begin
           --BWP-1184 glopez utiliza el json_object para construir json
           -- Esto asegura que el json estee correcto
           begin
             select json_object('nom_beneficiario' VALUE v_pri_nombre||' '||v_pri_apellido,
                                'nom_empresa' VALUE nvl(v_empresa, ' '),
                                'clave' VALUE to_char(v_clave_aux),
                                'cant_dias' VALUE v_dias  )
             into v_inf_deb_json
             from dual;
             exception
               when others then
                 return -9;
           end;  
             IF v_dir_correo IS NOT NULL AND v_tip_pro_cliente IS NOT NULL THEN
               -- NVB-380 - Enviamos por ba_env_correos
               paw_bem.lp_env_tra_notificacion(p_cod_persona, v_tip_pro_cliente, v_inf_deb_json, null, retError );
               if retError.error = 'S' then
                return -10;
               end if;
              ElSE
                 RETURN - 8; --Correo inexistente
              END IF;
            end;

       END IF;

     WHEN 'R' THEN
        --La acción es cambiar la contraseña
        DECLARE
           i NUMBER;
        BEGIN
           UPDATE bw_ope_claves
              SET cla_verificador = v_salt,
                  clave           = v_clave,
                  est_clave       = 'N',
                  can_intentos    = 0
            WHERE cod_persona = p_cod_persona
              AND tip_clave = p_tip_clave
              AND (
                   (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR 
                   (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
                  );          
           i := SQL%ROWCOUNT;
           IF i = 0 THEN
              -- no se actualizó ningun registro
              RETURN - 3;
           END IF;
           lp_cla_reg_operacion(p_cod_persona, p_accion, p_cod_per_vinculada, p_tip_clave);
        EXCEPTION
           WHEN OTHERS THEN
              RETURN - 2;
        END;
  WHEN 'A' THEN
    /*
      BWP-471 - glopez
    */
     declare
     v_res number; --Inicializamo
     begin
       --Llamamos a la funcion que creamos, debe de responder con un numero negativo.
       --Retorna 0 si esta todo OK
       v_res := fu_val_vul_cla(p_cod_persona, p_clave);
       IF v_res <> 0 THEN
        RETURN  v_res;
       END IF;    
     end;
     -- verificamos si la clave ya está en uso
     /*
      BWP-471 - glopez - Se comenta por que se va utilizar la validacion nueva
    */
     -- verificamos si la clave ya está en uso
    /* IF fu_val_vul_claves(p_cod_persona, p_clave) = 'N' THEN
        RETURN - 6;
     END IF;*/
     -- actualizar clave nueva y estado
     UPDATE bw_ope_claves
        SET clave           = v_clave,
            cla_verificador = v_salt,
            fec_cam_clave   = SYSDATE,
            fec_ult_acceso  = SYSDATE,
            can_intentos    = 0,           
            est_clave       = 'M'
      WHERE cod_persona = p_cod_persona
        AND ((p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR
             (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
            )
        AND tip_clave = p_tip_clave;
     -- controlamos si hubo actualización
     IF SQL%NOTFOUND THEN
        -- no se actualizó ningun registro
        RETURN - 3;
     END IF;           
     lp_cla_reg_operacion(p_cod_persona, p_accion, p_cod_per_vinculada, p_tip_clave);
  END CASE;

  RETURN lower(v_clave);
END;

/*
--cambia la clave de operaciones del usuario, recibe el hash md5 de la clave actual
--el hash md5 de la clave nueva y el codigo de persona
function fu_cam_ope_clave(p_cla_actual in varchar2,p_cla_nueva in varchar2, p_cod_persona in varchar2,p_cod_per_vinculada in varchar2, p_tip_clave in varchar2) 
  return number is
   v_aux  number;
begin
  v_aux:= FU_VAL_OPE_CLAVE (p_cla_actual, p_cod_persona,p_cod_per_vinculada,p_tip_clave);
  if(v_aux=0) then
    v_aux:=FU_GEN_OPE_CLAVE (p_cla_nueva , p_cod_persona,p_cod_per_vinculada ,'R', v_aux); --cambiaR
    if(v_aux=0) then
      lp_cla_reg_operacion(p_cod_persona,'R',p_cod_per_vinculada);
           IF p_cod_per_vinculada IS NULL THEN
              UPDATE bw_ope_claves
                 SET est_clave       = 'M'
               WHERE cod_persona = p_cod_persona
                 AND cod_per_vinculada IS NULL;
           ELSE
              UPDATE bw_ope_claves
                 SET est_clave       = 'M'
               WHERE cod_persona = p_cod_persona
                 AND cod_per_vinculada = p_cod_per_vinculada;
           END IF;
      return 0;
    end if;
  else
     return v_aux-20;
  end if;
  return 0;
end;
*/

-- Agregado para control de límite global de operaciones
-- se obtiene la cantidad total de movimientos por día de cod_persona y de su cuenta
procedure lp_obt_can_movimiento(p_cod_tip_mensaje IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                                p_cod_ente        IN ge_entes.cod_ente%TYPE,
                                p_cod_persona     IN ba_personas.cod_persona%TYPE, 
                                p_nro_cuenta      IN ge_cta_clientes.nro_cuenta%TYPE,
                                p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE, 
                                p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE, 
                                p_can_tra_cuenta  OUT ge_movimientos.monto%TYPE, 
                                p_can_tra_persona OUT ge_movimientos.monto%TYPE,
                                p_tip_persona IN ba_personas.tipo%TYPE ) is 

  -- auxiliares
  v_aux_can_tra_cuenta  NUMBER;
  v_aux_can_tra_persona NUMBER;
  v_aux_can_tra_cuenta_tdc  NUMBER;
  v_aux_can_tra_persona_tdc NUMBER;
  v_mod_reg_pago VARCHAR2(1) := 'N';
  v_tipo_per    ba_personas.tipo%TYPE :=  p_tip_persona; --NVB-2263
  v_cod_usu_mov        VARCHAR2(4000) := fug_obt_pardinamico('COD_USU_MOV_CANALES');    
  begin
    p_can_tra_cuenta   := 0;
    p_can_tra_persona  := 0;
    
    -- Si no esta configurado ningun usuario en el parametro agregamos por defecto 
    -- los usuarios de la banca 
    IF v_cod_usu_mov IS NULL THEN  
       v_cod_usu_mov := ','||c_usu_operativo_emp||','||c_usu_operativo_fis||',';
    ELSE      
       v_cod_usu_mov := ','||v_cod_usu_mov||',';
    END IF;
       
  
    -- puede existir proveedores que tengan debito uno a uno
    IF p_cod_tip_mensaje = '075' THEN
       BEGIN
          v_mod_reg_pago := nvl(TRIM(fug_obt_parentes(p_cod_ente, 'MOD_REG_PAG_PRV')), 'N'); /* N=Normal, P=Por operación*/
       EXCEPTION
          WHEN OTHERS THEN
             v_mod_reg_pago := 'N';
       END;
    END IF;
    
    --NVB-2263 - Para el caso de unipersonal el tipo de la persona debe ser F
    -- Eso por que al llamar a fu_val_cta_limite controla de que tipo es el principal de la cuenta
    begin
      if v_tipo_per = 'J' and
        nvl(fug_obt_naturaleza(p_cod_persona ), 'X') = nvl(fug_obt_pardinamico('COD_NAT_UNIPERSONAL'), 'X')  then -- 21 = unipersonal
        v_tipo_per := 'F'; --seteamos a fisica
      end if;
    end;
    -- ----------------------------------------
    -- obtengo la suma de todos los movimientos
    -- ----------------------------------------
    -- -------------------
    -- movimientos del día
    -- -------------------
    if p_cod_tip_mensaje = '033' then -- pago de aduanas tiene 4 tipo de transacciones padre
       SELECT COUNT(CASE WHEN gm.nro_cuenta = p_nro_cuenta THEN gm.monto END),
              COUNT(gm.monto)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM ge_movimientos gm
        WHERE gm.nro_cuenta IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gm.estado = 'N'
          AND gm.reversado = 'N'
          AND gm.cod_transaccion = p_cod_transaccion
          AND gm.cod_tra_padre IN (219,220,222,226)
          AND gm.cod_usuario in (c_usu_operativo_emp, c_usu_operativo_fis )
          AND trunc(gm.fec_insercion) = trunc(SYSDATE);
    elsif p_cod_tip_mensaje = '029' then
        SELECT COUNT(CASE WHEN gm.nro_cuenta = p_nro_cuenta THEN gm.monto END)- 1 ,
              COUNT(gm.monto) - 1
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona     
         FROM bw_lot_transferencias gm
          
                 WHERE gm.nro_cuenta IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
         AND trunc(gm.fec_pago) = trunc(SYSDATE)
         AND (gm.cod_estado IN ('E', 'C') OR gm.nro_lote = p_cod_tra_padre);
    elsif p_cod_tip_mensaje = '237' then
        SELECT COUNT(CASE WHEN gm.nro_cta_credito = p_nro_cuenta THEN gm.monto END) ,
              COUNT(gm.monto)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona     
         FROM bw_sol_transferencias gm
          
                 WHERE gm.nro_cta_credito IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and paw_bce.fu_val_cta_limite(a.nro_cuenta, 'F')='S'
        )
        AND trunc(gm.fec_insercion) = trunc(SYSDATE)
        AND gm.estado IN ('P', 'A');
    elsif p_cod_tip_mensaje = '035' then -- billetera zimple tiene 2 transacciones padre
       SELECT COUNT(CASE WHEN gm.nro_cuenta = p_nro_cuenta THEN gm.monto END),
              COUNT(gm.monto)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM ge_movimientos gm
        WHERE gm.nro_cuenta IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gm.estado = 'N'
          AND gm.reversado = 'N'
          AND gm.cod_transaccion = p_cod_transaccion
          AND gm.cod_tra_padre IN (490, 491) 
          AND (gm.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis ) or gm.cod_usuario like 'ATM%')
          AND trunc(gm.fec_insercion) = trunc(SYSDATE);      
    elsif p_cod_tip_mensaje in ('089') then -- pagos de servicios
       SELECT COUNT(CASE WHEN gm.nro_cuenta = p_nro_cuenta THEN gm.monto END),
              COUNT(gm.monto)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM ge_movimientos gm
        WHERE gm.nro_cuenta IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gm.estado = 'N'
          AND gm.reversado = 'N'
          AND gm.cod_transaccion = p_cod_transaccion
          AND gm.cod_tra_padre IN (8526)
          --AND (gm.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis ) OR gm.cod_usuario='IT' OR gm.cod_usuario like '%ATM%')
           -- para diferenciar servicios criticos de los no criticos
          AND ( 
               (p_cod_tip_mensaje = '091' AND gm.concepto LIKE '%-COD_WS_CRI:%') OR
               (p_cod_tip_mensaje IN ('089') AND gm.concepto NOT LIKE '%-COD_WS_CRI:%')
              )
          AND trunc(gm.fec_insercion) = trunc(SYSDATE);
      -- pago de servicios con tdc
          SELECT COUNT(CASE WHEN ptdc.nro_cuenta = p_nro_cuenta THEN ptdc.mto_transaccion
                 ELSE
                0
               END),
             COUNT(ptdc.mto_transaccion)
          INTO v_aux_can_tra_cuenta_tdc, v_aux_can_tra_persona_tdc
          FROM bw_pag_servicios ptdc
           WHERE ptdc.nro_cuenta IN
             (select a.nro_cuenta
              from ge_est_cuentas c, ge_cuentas a, ge_cta_clientes b
               where a.nro_cuenta = b.nro_cuenta
               and b.relacion in ('O', 'P', 'Y')
               and b.cod_persona = p_cod_persona
               and a.cod_modulo = c.cod_modulo
               and a.cod_modalidad = c.cod_modalidad
               and a.estado = c.estado
               and b.cod_modulo = 5
               and b.cod_modalidad <> 36
               and c.activo = 'S' -- solo cuentas activas
               and a.estado <> 'X' -- pendiente de verificacion
               and a.cod_moneda = 'GS'
               and fu_val_cta_limite(a.nro_cuenta, v_tipo_per) = 'S')
           AND ptdc.reversado = 'N'
           AND ptdc.cod_moneda = 'GS'
           AND ((p_cod_tip_mensaje = '091' AND
             ptdc.ser_concepto LIKE '%-COD_WS_CRI:%') OR
             (p_cod_tip_mensaje IN ('089') AND
             ptdc.ser_concepto NOT LIKE '%-COD_WS_CRI:%'))
           AND trunc(ptdc.fec_insercion) = trunc(SYSDATE);   
	      
    elsif p_cod_tip_mensaje in ('092', '093') then -- pago via Bancard QR. 092 debito en cuenta. 093 pago con TdC
      SELECT COUNT(*)
          INTO v_aux_can_tra_persona
      FROM bw_movimientos m
      WHERE m.cod_tip_mensaje = p_cod_tip_mensaje
      AND m.cod_per_principal = p_cod_persona
      AND trunc(m.fec_hora) = trunc(sysdate);
      
      SELECT COUNT(*)
          INTO v_aux_can_tra_cuenta
      FROM bw_movimientos m
      WHERE m.cod_tip_mensaje = p_cod_tip_mensaje
      AND m.cod_per_principal = p_cod_persona
      AND m.nro_cuenta = p_nro_cuenta
      AND trunc(m.fec_hora) = trunc(sysdate);
      
    elsif p_cod_tip_mensaje in ('070','071', '075') then -- pago de salario y proveedores se sumariza por código del ente
       SELECT COUNT(CASE WHEN gm.nro_cuenta = p_nro_cuenta THEN gm.monto END),
              COUNT(gm.monto)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM ge_movimientos gm
        WHERE gm.nro_cuenta IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
        )
          AND gm.estado = 'N'
          AND gm.reversado = 'N'
          AND gm.cod_transaccion = p_cod_transaccion
          AND (gm.nro_documento3 = p_cod_ente or gm.nro_documento2 = p_cod_ente)
          AND gm.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis )
          AND trunc(gm.fec_insercion) = trunc(SYSDATE);
    elsif p_cod_tip_mensaje <> '214' then
       SELECT COUNT(CASE WHEN gm.nro_cuenta = p_nro_cuenta THEN gm.monto END),
              COUNT(gm.monto)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM ge_movimientos gm
        WHERE gm.nro_cuenta IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gm.estado = 'N'
          AND gm.reversado = 'N'
          AND gm.cod_transaccion = p_cod_transaccion
          AND gm.cod_tra_padre = p_cod_tra_padre
          AND instr(v_cod_usu_mov,','||gm.cod_usuario||',') > 0
          --AND gm.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis )
          AND (p_cod_tip_mensaje NOT IN ('030','039', '036') OR 
               (p_cod_tip_mensaje = '039' AND gm.concepto LIKE 'Transf. terceros a % desde %') OR
               (p_cod_tip_mensaje = '030' AND gm.concepto NOT LIKE 'Transf. terceros a % desde %'
                                          AND gm.concepto NOT LIKE '% Ope. Cambio %') OR
               -- para diferenciar transferencias propias de terceros y pre-pactadas
               (p_cod_tip_mensaje = '036' AND gm.nro_documento3 IS NULL)
               -- para diferenciar transferencias sipap que entran como pago a proveedores
              ) 
          AND trunc(gm.fec_insercion) = trunc(SYSDATE);
    end if;  
    
    p_can_tra_cuenta   := p_can_tra_cuenta + nvl(v_aux_can_tra_cuenta, 0) + nvl(v_aux_can_tra_cuenta_tdc, 0);
    p_can_tra_persona  := p_can_tra_persona + nvl(v_aux_can_tra_persona, 0) + nvl(v_aux_can_tra_persona_tdc, 0);
    
    -- ---------------------
    -- movimientos nocturnos
    -- ---------------------
    if p_cod_tip_mensaje = '033' then -- pago de aduanas tiene 4 tipo de transacciones padre
       SELECT COUNT(CASE WHEN gnoc.nro_cuenta = p_nro_cuenta THEN gnoc.monto END),
              COUNT(gnoc.monto)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM ge_movimientos_noc gnoc
        WHERE gnoc.nro_cuenta IN
        (
          select a.nro_cuenta
            from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
           where a.nro_cuenta = b.nro_cuenta
             and b.relacion in ('O','P','Y')
             and b.cod_persona = p_cod_persona
             and a.cod_modulo = c.cod_modulo
             and a.cod_modalidad = c.cod_modalidad
             and a.estado = c.estado
             and b.cod_modulo != 7
             and b.cod_modalidad <> 36
             and c.activo = 'S'  -- solo cuentas activas
             and a.estado <> 'X' -- pendiente de verificación
             and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gnoc.estado = 'N'
          AND gnoc.reversado = 'N'
          AND gnoc.cod_transaccion = p_cod_transaccion       
          AND gnoc.cod_tra_padre IN (219,220,222,226)
          AND gnoc.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis )
          AND trunc(gnoc.fec_insercion) = trunc(SYSDATE);
    elsif p_cod_tip_mensaje = '035' then -- billetera zimple tiene 2 transacciones padre
       SELECT COUNT(CASE WHEN gnoc.nro_cuenta = p_nro_cuenta THEN gnoc.monto END),
              COUNT(gnoc.monto)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM ge_movimientos_noc gnoc
        WHERE gnoc.nro_cuenta IN
        (
          select a.nro_cuenta
            from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
           where a.nro_cuenta = b.nro_cuenta
             and b.relacion in ('O','P','Y')
             and b.cod_persona = p_cod_persona
             and a.cod_modulo = c.cod_modulo
             and a.cod_modalidad = c.cod_modalidad
             and a.estado = c.estado
             and b.cod_modulo != 7
             and b.cod_modalidad <> 36
             and c.activo = 'S'  -- solo cuentas activas
             and a.estado <> 'X' -- pendiente de verificación
             and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gnoc.estado = 'N'
          AND gnoc.reversado = 'N'
          AND gnoc.cod_transaccion = p_cod_transaccion       
          AND gnoc.cod_tra_padre IN (490, 491)
          AND (gnoc.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis ) or gnoc.cod_usuario like 'ATM%')
          AND trunc(gnoc.fec_insercion) = trunc(SYSDATE);      
    elsif p_cod_tip_mensaje in ('089') then -- pagos de servicios
       SELECT COUNT(CASE WHEN gnoc.nro_cuenta = p_nro_cuenta THEN gnoc.monto END),
              COUNT(gnoc.monto)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM ge_movimientos_noc gnoc
        WHERE gnoc.nro_cuenta IN
        (
          select a.nro_cuenta
            from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
           where a.nro_cuenta = b.nro_cuenta
             and b.relacion in ('O','P','Y')
             and b.cod_persona = p_cod_persona
             and a.cod_modulo = c.cod_modulo
             and a.cod_modalidad = c.cod_modalidad
             and a.estado = c.estado
             and b.cod_modulo != 7
             and b.cod_modalidad <> 36
             and c.activo = 'S'  -- solo cuentas activas
             and a.estado <> 'X' -- pendiente de verificación
             and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gnoc.estado = 'N'
          AND gnoc.reversado = 'N'
          AND gnoc.cod_transaccion = p_cod_transaccion       
          AND gnoc.cod_tra_padre IN (8526)
          --AND (gnoc.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis ) OR gnoc.cod_usuario='IT' OR gnoc.cod_usuario like '%ATM%')
           -- para diferenciar servicios criticos de los no criticos
          AND ( 
               (p_cod_tip_mensaje = '091' AND gnoc.concepto LIKE '%-COD_WS_CRI:%') OR
               (p_cod_tip_mensaje IN ('089') AND gnoc.concepto NOT LIKE '%-COD_WS_CRI:%')
              )          
          AND trunc(gnoc.fec_insercion) = trunc(SYSDATE);    
    elsif p_cod_tip_mensaje in ('070', '071','075') then -- pago de salario y proveedores se sumariza por código del ente
       SELECT COUNT(CASE WHEN gnoc.nro_cuenta = p_nro_cuenta THEN gnoc.monto END),
              COUNT(gnoc.monto)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM ge_movimientos_noc gnoc
        WHERE gnoc.nro_cuenta IN
        (
          select a.nro_cuenta
            from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
           where a.nro_cuenta = b.nro_cuenta
             and b.relacion in ('O','P','Y')
             and b.cod_persona = p_cod_persona
             and a.cod_modulo = c.cod_modulo
             and a.cod_modalidad = c.cod_modalidad
             and a.estado = c.estado
             and b.cod_modulo != 7
             and b.cod_modalidad <> 36
             and c.activo = 'S'  -- solo cuentas activas
             and a.estado <> 'X' -- pendiente de verificación
        )
          AND gnoc.estado = 'N'
          AND gnoc.reversado = 'N'
          AND gnoc.cod_transaccion = p_cod_transaccion       
          AND (gnoc.nro_documento3 = p_cod_ente or gnoc.nro_documento2 = p_cod_ente)
          AND gnoc.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis )
          AND trunc(gnoc.fec_insercion) = trunc(SYSDATE);    
    elsif p_cod_tip_mensaje <> '214' then
       SELECT COUNT(CASE WHEN gnoc.nro_cuenta = p_nro_cuenta THEN gnoc.monto END),
              COUNT(gnoc.monto)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM ge_movimientos_noc gnoc
        WHERE gnoc.nro_cuenta IN
        (
          select a.nro_cuenta
            from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
           where a.nro_cuenta = b.nro_cuenta
             and b.relacion in ('O','P','Y')
             and b.cod_persona = p_cod_persona
             and a.cod_modulo = c.cod_modulo
             and a.cod_modalidad = c.cod_modalidad
             and a.estado = c.estado
             and b.cod_modulo != 7
             and b.cod_modalidad <> 36
             and c.activo = 'S'  -- solo cuentas activas
             and a.estado <> 'X' -- pendiente de verificación
             and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gnoc.estado = 'N'
          AND gnoc.reversado = 'N'
          AND gnoc.cod_transaccion = p_cod_transaccion       
          AND gnoc.cod_tra_padre = p_cod_tra_padre
          AND instr(v_cod_usu_mov,','||gnoc.cod_usuario||',') > 0
          --AND gnoc.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis )
          AND (p_cod_tip_mensaje NOT IN ('030','039','036') OR 
               (p_cod_tip_mensaje = '039' AND gnoc.concepto LIKE 'Transf. terceros a % desde %') OR
               (p_cod_tip_mensaje = '030' AND gnoc.concepto NOT LIKE 'Transf. terceros a % desde %'
                                          AND gnoc.concepto NOT LIKE '% Ope. Cambio %') OR
               -- para diferenciar transferencias propias de terceros y pre-pactadas
               (p_cod_tip_mensaje = '036' AND gnoc.nro_documento3 IS NULL)
                -- para diferenciar transferencias sipap que entran como pago a proveedores
              ) 
          AND trunc(gnoc.fec_insercion) = trunc(SYSDATE);
    end if;  
    
    p_can_tra_cuenta   := p_can_tra_cuenta + nvl(v_aux_can_tra_cuenta, 0) + nvl(v_aux_can_tra_cuenta_tdc, 0);
    p_can_tra_persona  := p_can_tra_persona + nvl(v_aux_can_tra_persona, 0) + nvl(v_aux_can_tra_cuenta_tdc, 0);
    
    -- ----------------------
    -- movimientos pendientes
    -- ----------------------
   /* SELECT COUNT(CASE WHEN mpend.nro_cuenta = p_nro_cuenta THEN mpend.monto END),
           COUNT(mpend.monto)*/
    SELECT SUM(CASE WHEN mpend.nro_cuenta = p_nro_cuenta THEN decode(v_mod_reg_pago, 'N', 1, mpend.cantidad) ELSE 0 END),
           SUM(decode(v_mod_reg_pago, 'N', 1, mpend.cantidad)) 
      INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
      FROM bw_mov_pendientes mpend
     WHERE mpend.nro_cuenta IN
     (
      select a.nro_cuenta
        from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion in ('O','P','Y')
         and b.cod_persona = p_cod_persona
         and a.cod_modulo = c.cod_modulo
         and a.cod_modalidad = c.cod_modalidad
         and a.estado = c.estado
         and b.cod_modulo != 7
         and b.cod_modalidad <> 36
         and c.activo = 'S'  -- solo cuentas activas
         and a.estado <> 'X' -- pendiente de verificación
         and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
     )
       AND mpend.cod_tip_mensaje = p_cod_tip_mensaje
       AND mpend.estado IN ('P', 'I')
       AND trunc(mpend.fec_insercion) = trunc(SYSDATE);
       
    p_can_tra_cuenta   := p_can_tra_cuenta + nvl(v_aux_can_tra_cuenta, 0);
    p_can_tra_persona  := p_can_tra_persona + nvl(v_aux_can_tra_persona, 0);
    
    -- ------------------------------------------------------------
    -- pago a proveedores puede tener movimientos aún no procesados
    -- ------------------------------------------------------------
    if p_cod_tip_mensaje = '075' then
       IF v_mod_reg_pago = 'N' THEN
          SELECT COUNT(CASE WHEN pagpro.nro_cta_debito = p_nro_cuenta THEN pagpro.referencia END),
                 COUNT(pagpro.referencia)
            INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
            FROM 
            (
             SELECT DISTINCT referencia, nro_cta_debito
               FROM ge_pag_proveedores
              WHERE cod_ente = p_cod_ente
                AND estado = 'C'
                AND trunc(fec_insercion) = trunc(sysdate)
            ) pagpro;
       ELSE
          SELECT COUNT(CASE WHEN pagpro.nro_cta_debito = p_nro_cuenta THEN pagpro.referencia END),
                 COUNT(pagpro.referencia)
            INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
            FROM ge_pag_proveedores pagpro
           WHERE cod_ente = p_cod_ente
             AND estado = 'C'
             AND trunc(fec_insercion) = trunc(sysdate);
       END IF;
 
       p_can_tra_cuenta   := p_can_tra_cuenta + nvl(v_aux_can_tra_cuenta, 0);
       p_can_tra_persona  := p_can_tra_persona + nvl(v_aux_can_tra_persona, 0);
    end if;
    
    -- -------------------------------------
    -- Transferencias con contrato de cambio
    -- -------------------------------------
    if p_cod_tip_mensaje = '214' then
       SELECT COUNT(CASE WHEN lop.cta_ref_contra3 = p_nro_cuenta THEN lop.mto_contra3 END),
              COUNT(lop.mto_contra3)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM lc_ope_pendientes lop
        WHERE lop.cta_ref_contra3 IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND lop.liquidado = 'S'
          AND lop.ope_homebanking='S'
          AND trunc(lop.fec_insercion) = trunc(sysdate);
          
       p_can_tra_cuenta   := p_can_tra_cuenta + nvl(v_aux_can_tra_cuenta, 0);
       p_can_tra_persona  := p_can_tra_persona + nvl(v_aux_can_tra_persona, 0);
       
       -- arbitraje con contrato de cambio
       SELECT COUNT(CASE WHEN lop.cta_ref_contra3 = p_nro_cuenta THEN lop.mto_contra3 END),
              COUNT(lop.mto_contra3)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM lc_ope_pen_cambios lop
        WHERE lop.cta_ref_contra3 IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND lop.liquidado = 'S'
          AND lop.ope_homebanking = 'S'
          AND lop.cod_tip_operacion = 61 -- compra debito cuenta cliente
          AND trunc(lop.fec_insercion) = trunc(sysdate);
          
       p_can_tra_cuenta   := p_can_tra_cuenta + nvl(v_aux_can_tra_cuenta, 0);
       p_can_tra_persona  := p_can_tra_persona + nvl(v_aux_can_tra_persona, 0);
    end if;
    
    -- ------------------------------------------------------------
    -- pago de nominas en batch puede tener movimientos aún no procesados
    -- ------------------------------------------------------------
    if p_cod_tip_mensaje = '070' then
       SELECT COUNT(CASE WHEN psl.nro_cta_debito = p_nro_cuenta THEN psl.mto_debito END),
              COUNT(psl.mto_debito)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM ge_pag_sue_lotes psl
        WHERE psl.cod_ente = p_cod_ente
          AND psl.estado = 'P'
          AND trunc(psl.fec_insercion) = trunc(sysdate);
         
       p_can_tra_cuenta   := p_can_tra_cuenta + nvl(v_aux_can_tra_cuenta, 0);
       p_can_tra_persona  := p_can_tra_persona + nvl(v_aux_can_tra_persona, 0);
    end if;
    -- transferencias interbancarias pueden tener fechas de pago a futuro
    if p_cod_tip_mensaje = '036' then
       SELECT COUNT(CASE WHEN snptra.nro_cta_solicitante = p_nro_cuenta THEN snptra.monto END),
              COUNT(snptra.monto)
         INTO v_aux_can_tra_cuenta, v_aux_can_tra_persona
         FROM ge_snp_transferencias snptra
        WHERE snptra.cod_per_solicitante = p_cod_persona
          AND snptra.estado = 'A'
          AND snptra.situacion = 'P'
          --AND snptra.usu_insercion in (c_usu_operativo_emp,c_usu_operativo_fis )
          AND instr(v_cod_usu_mov,','||snptra.usu_insercion||',') > 0
          AND trunc(snptra.fec_insercion) <= trunc(sysdate)
          AND snptra.fecha is NULL;
         
       p_can_tra_cuenta   := p_can_tra_cuenta + nvl(v_aux_can_tra_cuenta, 0);
       p_can_tra_persona  := p_can_tra_persona + nvl(v_aux_can_tra_persona, 0);
    end if;
  end;

-- Agregado para control de límite global de operaciones
-- se obtiene el total de movimientos por día de cod_persona y de su cuenta
procedure pr_obt_tot_movimiento(p_cod_tip_mensaje IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                                p_cod_ente        IN ge_entes.cod_ente%TYPE,
                                p_cod_persona     IN ba_personas.cod_persona%TYPE, 
                                p_nro_cuenta      IN ge_cta_clientes.nro_cuenta%TYPE, 
                                p_cod_moneda      IN ba_monedas.cod_moneda%TYPE,
                                p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE, 
                                p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE, 
                                p_mto_tra_cuenta  OUT ge_movimientos.monto%TYPE, 
                                p_mto_tra_persona OUT ge_movimientos.monto%TYPE,
                                p_tip_persona IN ba_personas.tipo%TYPE) is 

  -- auxiliares
  v_aux_mto_tra_cuenta  ge_movimientos.monto%TYPE;
  v_aux_mto_tra_persona ge_movimientos.monto%TYPE;
  v_aux_mto_tra_cuenta_tdc  bw_pag_servicios.mto_transaccion%TYPE;
  v_aux_mto_tra_persona_tdc bw_pag_servicios.mto_transaccion%TYPE;
  v_tipo_per    ba_personas.tipo%TYPE :=  p_tip_persona; --NVB-2263
  v_cod_usu_mov        VARCHAR2(4000) := fug_obt_pardinamico('COD_USU_MOV_CANALES');    
                                  
  begin
    -- Si no esta configurado ningun usuario en el parametro agregamos por defecto 
    -- los usuarios de la banca 
    IF v_cod_usu_mov IS NULL THEN  
       v_cod_usu_mov := ','||c_usu_operativo_emp||','||c_usu_operativo_fis||',';
    ELSE 
       v_cod_usu_mov := ','||v_cod_usu_mov||',';     
    END IF;
  
    --NVB-2263 - Para el caso de unipersonal el tipo de la persona debe ser F
    -- Eso por que al llamar a fu_val_cta_limite controla de que tipo es el principal de la cuenta
    begin
      if v_tipo_per = 'J' and
        nvl(fug_obt_naturaleza(p_cod_persona ), 'X') = nvl(fug_obt_pardinamico('COD_NAT_UNIPERSONAL'), 'X')  then -- 21 = unipersonal
        v_tipo_per := 'F'; --seteamos a fisica
      end if;
    end;
    p_mto_tra_cuenta   := 0;
    p_mto_tra_persona  := 0;
    -- ----------------------------------------
    -- obtengo la suma de todos los movimientos
    -- ----------------------------------------
    -- -------------------
    -- movimientos del día
    -- -------------------
    if p_cod_tip_mensaje = '033' then -- pago de aduanas tiene 4 tipo de transacciones padre
       SELECT SUM(CASE WHEN gm.nro_cuenta = p_nro_cuenta THEN gm.monto ELSE 0 END),
              SUM(gm.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM ge_movimientos gm
        WHERE gm.nro_cuenta IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and a.cod_moneda = p_cod_moneda
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gm.estado = 'N'
          AND gm.reversado = 'N'
          AND gm.cod_transaccion = p_cod_transaccion
          AND gm.cod_moneda = p_cod_moneda
          AND gm.cod_tra_padre IN (219,220,222,226) 
          AND gm.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis )
          AND trunc(gm.fec_insercion) = trunc(SYSDATE);
    elsif p_cod_tip_mensaje = '029' then -- Transferencias en lotes
        SELECT SUM(CASE WHEN gm.nro_cuenta = p_nro_cuenta THEN gm.monto ELSE 0 END),
              SUM(gm.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona 
         FROM bw_lot_transferencias gm
         WHERE gm.nro_cuenta IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
         AND trunc(gm.fec_pago) = trunc(SYSDATE)    
         AND (gm.cod_estado IN ('E', 'C'));
         
    elsif p_cod_tip_mensaje = '237' then
      
         SELECT SUM(CASE WHEN gm.nro_cta_credito = p_nro_cuenta THEN gm.monto ELSE 0 END),
              SUM(gm.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona 
         FROM bw_sol_transferencias gm
         WHERE gm.nro_cta_credito IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and fu_val_cta_limite(a.nro_cuenta,'F') = 'S'
        )
         AND trunc(gm.fec_insercion) = trunc(SYSDATE)    
         AND (gm.estado IN ('P', 'A'));
    
    elsif p_cod_tip_mensaje = '035' then -- billetera zimple tiene 2 transacciones padre
        SELECT SUM(CASE WHEN gm.nro_cuenta = p_nro_cuenta THEN gm.monto ELSE 0 END),
              SUM(gm.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM ge_movimientos gm
        WHERE gm.nro_cuenta IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and a.cod_moneda = p_cod_moneda
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gm.estado = 'N'
          AND gm.reversado = 'N'
          AND gm.cod_transaccion = p_cod_transaccion
          AND gm.cod_moneda = p_cod_moneda
          AND gm.cod_tra_padre IN (490, 491) 
          AND (gm.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis ) or gm.cod_usuario like 'ATM%')
          AND trunc(gm.fec_insercion) = trunc(SYSDATE);      
    elsif p_cod_tip_mensaje in ('089') then -- pagos de servicios
       SELECT SUM(CASE WHEN gm.nro_cuenta = p_nro_cuenta THEN gm.monto ELSE 0 END),
              SUM(gm.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM ge_movimientos gm
        WHERE gm.nro_cuenta IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and a.cod_moneda = p_cod_moneda
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gm.estado = 'N'
          AND gm.reversado = 'N'
          AND gm.cod_transaccion = p_cod_transaccion
          AND gm.cod_moneda = p_cod_moneda
          AND gm.cod_tra_padre IN (8526)
          --AND (gm.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis ) OR gm.cod_usuario='IT' OR gm.cod_usuario like '%ATM%')
           -- para diferenciar servicios criticos de los no criticos
          AND ( 
               (p_cod_tip_mensaje = '091' AND gm.concepto LIKE '%-COD_WS_CRI:%') OR
               (p_cod_tip_mensaje IN ('089') AND gm.concepto NOT LIKE '%-COD_WS_CRI:%')
              )
          AND trunc(gm.fec_insercion) = trunc(SYSDATE);
      -- Para pagos realizados con tarjeta de credito.
      SELECT SUM(CASE
             WHEN tdc.nro_cuenta = p_nro_cuenta THEN
              tdc.mto_transaccion
             END),
         SUM(tdc.mto_transaccion)
      INTO v_aux_mto_tra_cuenta_tdc, v_aux_mto_tra_persona_tdc
      FROM bw_pag_servicios tdc
       WHERE tdc.nro_cuenta IN
         (select a.nro_cuenta
          from ge_est_cuentas c, ge_cuentas a, ge_cta_clientes b
           where a.nro_cuenta = b.nro_cuenta
           and b.relacion in ('O', 'P', 'Y')
           and b.cod_persona = p_cod_persona
           and a.cod_modulo = c.cod_modulo
           and a.cod_modalidad = c.cod_modalidad
           and a.estado = c.estado
           and b.cod_modulo = 5
           and b.cod_modalidad <> 36
           and c.activo = 'S' -- solo cuentas activas
           and a.estado <> 'X' -- pendiente de verificacion
           and fu_val_cta_limite(a.nro_cuenta, v_tipo_per) = 'S')
       and tdc.reversado = 'N'
        -- para diferenciar servicios criticos de los no criticos
       and ((p_cod_tip_mensaje = '091' AND
         tdc.ser_concepto LIKE '%-COD_WS_CRI:%') OR
         (p_cod_tip_mensaje IN ('089') AND
         tdc.ser_concepto NOT LIKE '%-COD_WS_CRI:%'))
       and trunc(tdc.fec_insercion) = trunc(SYSDATE);
    
        --------------------------
    elsif p_cod_tip_mensaje in ('070', '071','075') then -- pago de salario y proveedores se sumariza por código del ente
       SELECT SUM(CASE WHEN gm.nro_cuenta = p_nro_cuenta THEN gm.monto ELSE 0 END),
              SUM(gm.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM ge_movimientos gm
        WHERE gm.nro_cuenta IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and a.cod_moneda = p_cod_moneda
        )
          AND gm.estado = 'N'
          AND gm.reversado = 'N'
          AND gm.cod_transaccion = p_cod_transaccion
          AND gm.cod_moneda = p_cod_moneda
          AND (gm.nro_documento3 = p_cod_ente or gm.nro_documento2 = p_cod_ente)          
          AND gm.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis )
          AND trunc(gm.fec_insercion) = trunc(SYSDATE);
    elsif p_cod_tip_mensaje <> '214' then
       SELECT SUM(CASE WHEN gm.nro_cuenta = p_nro_cuenta THEN gm.monto ELSE 0 END),
              SUM(gm.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM ge_movimientos gm
        WHERE gm.nro_cuenta IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and a.cod_moneda = p_cod_moneda
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gm.estado = 'N'
          AND gm.reversado = 'N'
          AND gm.cod_transaccion = p_cod_transaccion
          AND gm.cod_moneda = p_cod_moneda
          AND gm.cod_tra_padre = p_cod_tra_padre
          AND instr(v_cod_usu_mov,','||gm.cod_usuario||',') > 0
          --AND gm.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis )
          AND (p_cod_tip_mensaje NOT IN ('030','039', '036') OR 
               (p_cod_tip_mensaje = '039' AND gm.concepto LIKE 'Transf. terceros a % desde %') OR
               (p_cod_tip_mensaje = '030' AND gm.concepto NOT LIKE 'Transf. terceros a % desde %'
                                          AND gm.concepto NOT LIKE '% Ope. Cambio %') OR
               -- para diferenciar transferencias propias de terceros y pre-pactadas
               (p_cod_tip_mensaje = '036' AND gm.nro_documento3 IS NULL)
               -- para diferenciar transferencias sipap que entran como pago a proveedores
              ) 
          AND trunc(gm.fec_insercion) = trunc(SYSDATE);
    end if;  
    
    p_mto_tra_cuenta   := p_mto_tra_cuenta + nvl(v_aux_mto_tra_cuenta, 0) + nvl(v_aux_mto_tra_cuenta_tdc, 0);
    p_mto_tra_persona  := p_mto_tra_persona + nvl(v_aux_mto_tra_persona, 0) + nvl(v_aux_mto_tra_persona_tdc, 0);
    
    -- ---------------------
    -- movimientos nocturnos
    -- ---------------------
    if p_cod_tip_mensaje = '033' then -- pago de aduanas tiene 4 tipo de transacciones padre
       SELECT SUM(CASE WHEN gnoc.nro_cuenta = p_nro_cuenta THEN gnoc.monto ELSE 0 END),
              SUM(gnoc.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM ge_movimientos_noc gnoc
        WHERE gnoc.nro_cuenta IN
        (
          select a.nro_cuenta
            from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
           where a.nro_cuenta = b.nro_cuenta
             and b.relacion in ('O','P','Y')
             and b.cod_persona = p_cod_persona
             and a.cod_modulo = c.cod_modulo
             and a.cod_modalidad = c.cod_modalidad
             and a.estado = c.estado
             and b.cod_modulo != 7
             and b.cod_modalidad <> 36
             and c.activo = 'S'  -- solo cuentas activas
             and a.estado <> 'X' -- pendiente de verificación
             and a.cod_moneda = p_cod_moneda
             and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gnoc.estado = 'N'
          AND gnoc.reversado = 'N'
          AND gnoc.cod_transaccion = p_cod_transaccion       
          AND gnoc.cod_tra_padre IN (219,220,222,226)
          AND gnoc.cod_moneda = p_cod_moneda
          AND gnoc.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis )
          AND trunc(gnoc.fec_insercion) = trunc(SYSDATE);
    elsif p_cod_tip_mensaje = '035' then -- billetera zimple tiene 2 transacciones padre y viene con 
       SELECT SUM(CASE WHEN gnoc.nro_cuenta = p_nro_cuenta THEN gnoc.monto ELSE 0 END),
              SUM(gnoc.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM ge_movimientos_noc gnoc
        WHERE gnoc.nro_cuenta IN
        (
          select a.nro_cuenta
            from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
           where a.nro_cuenta = b.nro_cuenta
             and b.relacion in ('O','P','Y')
             and b.cod_persona = p_cod_persona
             and a.cod_modulo = c.cod_modulo
             and a.cod_modalidad = c.cod_modalidad
             and a.estado = c.estado
             and b.cod_modulo != 7
             and b.cod_modalidad <> 36
             and c.activo = 'S'  -- solo cuentas activas
             and a.estado <> 'X' -- pendiente de verificación
             and a.cod_moneda = p_cod_moneda
             and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gnoc.estado = 'N'
          AND gnoc.reversado = 'N'
          AND gnoc.cod_transaccion = p_cod_transaccion       
          AND gnoc.cod_tra_padre IN (490, 491)
          AND gnoc.cod_moneda = p_cod_moneda
          AND (gnoc.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis ) or gnoc.cod_usuario like 'ATM%')
          AND trunc(gnoc.fec_insercion) = trunc(SYSDATE);      
    elsif p_cod_tip_mensaje in ('089') then -- pagos de servicios
       SELECT SUM(CASE WHEN gnoc.nro_cuenta = p_nro_cuenta THEN gnoc.monto ELSE 0 END),
              SUM(gnoc.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM ge_movimientos_noc gnoc
        WHERE gnoc.nro_cuenta IN
        (
          select a.nro_cuenta
            from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
           where a.nro_cuenta = b.nro_cuenta
             and b.relacion in ('O','P','Y')
             and b.cod_persona = p_cod_persona
             and a.cod_modulo = c.cod_modulo
             and a.cod_modalidad = c.cod_modalidad
             and a.estado = c.estado
             and b.cod_modulo != 7
             and b.cod_modalidad <> 36
             and c.activo = 'S'  -- solo cuentas activas
             and a.estado <> 'X' -- pendiente de verificación
             and a.cod_moneda = p_cod_moneda
             and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gnoc.estado = 'N'
          AND gnoc.reversado = 'N'
          AND gnoc.cod_transaccion = p_cod_transaccion       
          AND gnoc.cod_tra_padre IN (8526)
          AND gnoc.cod_moneda = p_cod_moneda
          --AND (gnoc.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis ) OR gnoc.cod_usuario='IT' OR gnoc.cod_usuario like 'ATM%')
           -- para diferenciar servicios criticos de los no criticos
          AND ( 
               (p_cod_tip_mensaje = '091' AND gnoc.concepto LIKE '%-COD_WS_CRI:%') OR
               (p_cod_tip_mensaje IN ('089') AND gnoc.concepto NOT LIKE '%-COD_WS_CRI:%')
              )
          AND trunc(gnoc.fec_insercion) = trunc(SYSDATE);    
    elsif p_cod_tip_mensaje in ('070','071', '075') then -- pago de salario y proveedores se sumariza por código del ente
       SELECT SUM(CASE WHEN gnoc.nro_cuenta = p_nro_cuenta THEN gnoc.monto ELSE 0 END),
              SUM(gnoc.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM ge_movimientos_noc gnoc
        WHERE gnoc.nro_cuenta IN
        (
          select a.nro_cuenta
            from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
           where a.nro_cuenta = b.nro_cuenta
             and b.relacion in ('O','P','Y')
             and b.cod_persona = p_cod_persona
             and a.cod_modulo = c.cod_modulo
             and a.cod_modalidad = c.cod_modalidad
             and a.estado = c.estado
             and b.cod_modulo != 7
             and b.cod_modalidad <> 36
             and c.activo = 'S'  -- solo cuentas activas
             and a.estado <> 'X' -- pendiente de verificación
             and a.cod_moneda = p_cod_moneda
        )
          AND gnoc.estado = 'N'
          AND gnoc.reversado = 'N'
          AND gnoc.cod_transaccion = p_cod_transaccion       
          AND (gnoc.nro_documento3 = p_cod_ente or gnoc.nro_documento2 = p_cod_ente)
          AND gnoc.cod_moneda = p_cod_moneda
          AND gnoc.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis )
          AND trunc(gnoc.fec_insercion) = trunc(SYSDATE);    
    elsif p_cod_tip_mensaje <> '214' then
       SELECT SUM(CASE WHEN gnoc.nro_cuenta = p_nro_cuenta THEN gnoc.monto ELSE 0 END),
              SUM(gnoc.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM ge_movimientos_noc gnoc
        WHERE gnoc.nro_cuenta IN
        (
          select a.nro_cuenta
            from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
           where a.nro_cuenta = b.nro_cuenta
             and b.relacion in ('O','P','Y')
             and b.cod_persona = p_cod_persona
             and a.cod_modulo = c.cod_modulo
             and a.cod_modalidad = c.cod_modalidad
             and a.estado = c.estado
             and b.cod_modulo != 7
             and b.cod_modalidad <> 36
             and c.activo = 'S'  -- solo cuentas activas
             and a.estado <> 'X' -- pendiente de verificación
             and a.cod_moneda = p_cod_moneda
             and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND gnoc.estado = 'N'
          AND gnoc.reversado = 'N'
          AND gnoc.cod_transaccion = p_cod_transaccion       
          AND gnoc.cod_tra_padre = p_cod_tra_padre
          AND gnoc.cod_moneda = p_cod_moneda
          AND instr(v_cod_usu_mov,','||gnoc.cod_usuario||',') > 0
          --AND gnoc.cod_usuario in (c_usu_operativo_emp,c_usu_operativo_fis )
          AND (p_cod_tip_mensaje NOT IN ('030','039','036') OR 
               (p_cod_tip_mensaje = '039' AND gnoc.concepto LIKE 'Transf. terceros a % desde %') OR
               (p_cod_tip_mensaje = '030' AND gnoc.concepto NOT LIKE 'Transf. terceros a % desde %'
                                          AND gnoc.concepto NOT LIKE '% Ope. Cambio %') OR
               -- para diferenciar transferencias propias de terceros y pre-pactadas
               (p_cod_tip_mensaje = '036' AND gnoc.nro_documento3 IS NULL)
               -- para diferenciar transferencias sipap que entran como pago a proveedores
              ) 
          AND trunc(gnoc.fec_insercion) = trunc(SYSDATE);
    end if;  
    
    p_mto_tra_cuenta   := p_mto_tra_cuenta + nvl(v_aux_mto_tra_cuenta, 0);
    p_mto_tra_persona  := p_mto_tra_persona + nvl(v_aux_mto_tra_persona, 0);
    
    -- ----------------------
    -- movimientos pendientes
    -- ----------------------
    SELECT SUM(CASE WHEN mpend.nro_cuenta = p_nro_cuenta THEN mpend.monto ELSE 0 END),
           SUM(mpend.monto)
      INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
      FROM bw_mov_pendientes mpend
     WHERE mpend.nro_cuenta IN
     (
      select a.nro_cuenta
        from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion in ('O','P','Y')
         and b.cod_persona = p_cod_persona
         and a.cod_modulo = c.cod_modulo
         and a.cod_modalidad = c.cod_modalidad
         and a.estado = c.estado
         and b.cod_modulo != 7
         and b.cod_modalidad <> 36
         and c.activo = 'S'  -- solo cuentas activas
         and a.estado <> 'X' -- pendiente de verificación
         and a.cod_moneda = p_cod_moneda
         and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
     )
       AND mpend.cod_tip_mensaje = p_cod_tip_mensaje
       AND mpend.cod_moneda = p_cod_moneda
       AND mpend.estado IN ('P', 'I')
       AND trunc(mpend.fec_insercion) = trunc(SYSDATE);
       
    p_mto_tra_cuenta   := p_mto_tra_cuenta + nvl(v_aux_mto_tra_cuenta, 0);
    p_mto_tra_persona  := p_mto_tra_persona + nvl(v_aux_mto_tra_persona, 0);
    
    -- ------------------------------------------------------------
    -- pago a proveedores puede tener movimientos aún no procesados
    -- ------------------------------------------------------------
    if p_cod_tip_mensaje = '075' then
       SELECT SUM(CASE WHEN pagpro.nro_cta_debito = p_nro_cuenta THEN pagpro.monto ELSE 0 END),
              SUM(pagpro.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM ge_pag_proveedores pagpro
        WHERE pagpro.cod_ente = p_cod_ente
          AND pagpro.cod_moneda = p_cod_moneda
          AND pagpro.estado = 'C'
          AND trunc(pagpro.fec_insercion) = trunc(sysdate);
         
       p_mto_tra_cuenta   := p_mto_tra_cuenta + nvl(v_aux_mto_tra_cuenta, 0);
       p_mto_tra_persona  := p_mto_tra_persona + nvl(v_aux_mto_tra_persona, 0);
    end if;
    
     --SNP transferencias interbancarias pueden tener fechas de pago a futuro
    if p_cod_tip_mensaje = '036' then
       SELECT SUM(CASE WHEN snptra.nro_cta_solicitante = p_nro_cuenta THEN snptra.monto ELSE 0 END),
              SUM(snptra.monto)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM ge_snp_transferencias snptra
        WHERE snptra.cod_per_solicitante = p_cod_persona
          AND snptra.cod_moneda = p_cod_moneda
          AND snptra.estado = 'A'
          AND snptra.situacion = 'P'
          AND trunc(snptra.fec_insercion) <= trunc(sysdate)
          AND instr(v_cod_usu_mov,','||snptra.usu_insercion||',') > 0
          --AND snptra.usu_insercion in (c_usu_operativo_emp,c_usu_operativo_fis )
          AND snptra.fecha is NULL;

       p_mto_tra_cuenta   := p_mto_tra_cuenta + nvl(v_aux_mto_tra_cuenta, 0);
       p_mto_tra_persona  := p_mto_tra_persona + nvl(v_aux_mto_tra_persona, 0);
    end if;
    --SNP -------------------------------------
    -- Transferencias con contrato de cambio
    -- -------------------------------------
    if p_cod_tip_mensaje = '214' then
       SELECT SUM(CASE WHEN lop.cta_ref_contra3 = p_nro_cuenta THEN lop.mto_contra3 ELSE 0 END),
              SUM(lop.mto_contra3)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM lc_ope_pendientes lop
        WHERE lop.cta_ref_contra3 IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and a.cod_moneda = p_cod_moneda
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND lop.liquidado = 'S'
          AND lop.ope_homebanking='S'
          AND trunc(lop.fec_insercion) = trunc(sysdate);
          
       p_mto_tra_cuenta   := p_mto_tra_cuenta + nvl(v_aux_mto_tra_cuenta, 0);
       p_mto_tra_persona  := p_mto_tra_persona + nvl(v_aux_mto_tra_persona, 0);
       
       -- arbitraje con contrato
       SELECT SUM(CASE WHEN lop.cta_ref_contra3 = p_nro_cuenta THEN lop.mto_contra3 ELSE 0 END),
              SUM(lop.mto_contra3)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM lc_ope_pen_cambios lop
        WHERE lop.cta_ref_contra3 IN 
        (
         select a.nro_cuenta
           from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
          where a.nro_cuenta = b.nro_cuenta
            and b.relacion in ('O','P','Y')
            and b.cod_persona = p_cod_persona
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.estado = c.estado
            and b.cod_modulo != 7
            and b.cod_modalidad <> 36
            and c.activo = 'S'  -- solo cuentas activas
            and a.estado <> 'X' -- pendiente de verificación
            and a.cod_moneda = p_cod_moneda
            and fu_val_cta_limite(a.nro_cuenta,v_tipo_per)='S'
        )
          AND lop.liquidado = 'S'
          AND lop.ope_homebanking='S'
          AND lop.cod_tip_operacion = 61 -- compra con debito en cta. cliente
          AND trunc(lop.fec_insercion) = trunc(sysdate);
          
       p_mto_tra_cuenta   := p_mto_tra_cuenta + nvl(v_aux_mto_tra_cuenta, 0);
       p_mto_tra_persona  := p_mto_tra_persona + nvl(v_aux_mto_tra_persona, 0);
    end if;
    
    -- ------------------------------------------------------------
    -- pago de nominas en batch puede tener movimientos aún no procesados
    -- ------------------------------------------------------------
    if p_cod_tip_mensaje = '070' then
       SELECT SUM(CASE WHEN psl.nro_cta_debito = p_nro_cuenta THEN psl.mto_debito ELSE 0 END),
              SUM(psl.mto_debito)
         INTO v_aux_mto_tra_cuenta, v_aux_mto_tra_persona
         FROM ge_pag_sue_lotes psl
        WHERE psl.cod_ente = p_cod_ente
          AND psl.cod_moneda = p_cod_moneda
          AND psl.estado = 'P'
          AND trunc(psl.fec_insercion) = trunc(sysdate);
         
       p_mto_tra_cuenta   := p_mto_tra_cuenta + nvl(v_aux_mto_tra_cuenta, 0);
       p_mto_tra_persona  := p_mto_tra_persona + nvl(v_aux_mto_tra_persona, 0);
    end if;
  end;
  
  -- Obtiene el total de límite máximo operativo por mensaje
  
  -- Mensajes de respuesta  
     -- TK : armado de respuesta
     -- ------------------------ 
     -- 00 : el cliente puede operar libremente
     -- 01 : al cliente se le pide SOLO TOKEN
     -- 10 : al cliente se le pide SOLO Clave Transaccional
     -- 11 : al cliente se le pide Clave Transaccional + TOKEN
     -- -1 : no posee autorización - en Bitacora(ERROR el límite ha sido excedido)
     -- -2 : no posee autorización - en Bitacora(ERROR configuración soft-token inexistente)
     -- -3 : no posee autorización - en Bitacora(ERROR límite no definido para la operación)
     -- -4 : no posee autorización - en Bitacora(ERROR de validación de clave token en Vasco)
     
  -- OBS: se espera que p_nro_cuenta sea una cuenta asociada a p_cod_persona
  -- y a cod_moneda, para no sobrecargar con controles, que ya se deberían 
  -- de realizar antes de llamar a la función
  function fu_obt_limite(p_cod_tip_mensaje IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                         p_cod_persona     IN ba_personas.cod_persona%TYPE,
                         p_nro_cuenta      IN ge_cta_clientes.nro_cuenta%TYPE,
                         p_cod_moneda      IN ba_monedas.cod_moneda%TYPE,
                         p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE,
                         p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE,
                         p_monto           IN ge_movimientos.monto%TYPE,
                         p_modo            IN VARCHAR2,
                         p_cod_ente        IN ge_entes.cod_ente%TYPE DEFAULT NULL,
                         p_session         IN bw_sesiones.nro_sesion%type DEFAULT NULL,
                         p_nro_ip          IN bw_sesiones.nro_ip%type DEFAULT NULL,
                         p_cantidad        IN NUMBER DEFAULT 1,
                         p_cod_per_vinculada IN ba_personas.cod_persona%TYPE DEFAULT NULL)
    return varchar2 is
 
    v_can_tra_cuenta    NUMBER; -- cantidad de movimientos de la cuenta
    v_can_tra_persona   NUMBER; -- cantidad de movimientos de p_cod_persona
    v_can_maxima        NUMBER; -- límite de cantidad maxima definida 
    v_mto_tra_cuenta    ge_movimientos.monto%TYPE := 0; -- total de movimientos de la cuenta
    v_mto_tra_persona   ge_movimientos.monto%TYPE := 0; -- total de movimientos de p_cod_persona
    v_combinaciones     varchar2(3);
    v_cod_res           varchar2(2) := ''; -- mensaje de respuesta
    v_existe            BOOLEAN;     -- variable bandera
    v_tip_persona       bw_cla_lim_montos.tip_persona%TYPE;
    v_cod_persona       ba_personas.cod_persona%type;
    v_cod_per_vinculada ba_personas.cod_persona%type;
    v_tip_softoken varchar2(2) := 'F';
    v_obt_softToken     VARCHAR2(1);
    v_cod_per_control   ba_personas.cod_persona%TYPE;
    v_ctr_mto_limite    VARCHAR2(1); -- Control de Limite de monto por el cual se realizo P=Persona, C=Cuenta, G=General
    v_ctr_can_limite    VARCHAR2(1); -- Control de Limite de cantidades por el cual se realizo P=Persona, C=Cuenta, G=General
    v_mto_lim_minimo    NUMBER;      -- Monto minimo del rango por el cual se realizo en control de limite
    v_mto_lim_maximo    NUMBER;      -- Monto Maximo del rango por el cual se realizo en control de limite
    v_can_max_limite    NUMBER;      -- Cantidad Maximo del rango por el cual s
    v_bitacora          bw_bitacoras.dato%TYPE;
    --cursor para obtener los límites que caen dentro del rango de p_monto
    CURSOR c_lim(c_tip_mensaje   bw_cla_lim_montos.cod_tip_mensaje%TYPE,
                 c_cod_persona   ba_personas.cod_persona%TYPE,
                 c_nro_cuenta    ge_cta_clientes.nro_cuenta%TYPE,
                 c_tip_persona   bw_cla_lim_montos.tip_persona%TYPE,
                 c_cod_moneda    bw_cla_lim_montos.cod_moneda%TYPE) IS
    SELECT bclm.cod_tip_clave, bclm.mto_minimo, bclm.mto_maximo
      FROM bw_cla_lim_montos bclm
     WHERE bclm.tip_persona = c_tip_persona
       AND bclm.activo = 'A'
       AND bclm.cod_tip_mensaje = c_tip_mensaje
       AND bclm.cod_moneda = c_cod_moneda
       AND NVL(bclm.cod_persona, ' ') = NVL(c_cod_persona, ' ')
       AND NVL(bclm.nro_cuenta, ' ') = NVL(c_nro_cuenta, ' ');
    --cursor para obtener los límites que caen dentro del rango de p_monto
    PROCEDURE obt_lim_cantidad(p_persona     IN ba_personas.cod_persona%TYPE,
                               p_cuenta      IN ge_cta_clientes.nro_cuenta%TYPE,
                               p_tip_persona IN bw_cla_lim_cantidades.tip_persona%TYPE,
                               p_can_maxima OUT bw_cla_lim_cantidades.can_maxima%TYPE) IS
    BEGIN
      SELECT bwlc.can_maxima
        INTO p_can_maxima
        FROM bw_cla_lim_cantidades bwlc
       WHERE bwlc.tip_persona = p_tip_persona
         AND bwlc.estado = 'S'
         AND bwlc.cod_tip_mensaje = p_cod_tip_mensaje
         AND NVL(bwlc.cod_persona, ' ') = NVL(p_persona, ' ')
         AND NVL(bwlc.nro_cuenta, ' ') = NVL(p_cuenta, ' ');
    EXCEPTION
      WHEN OTHERS THEN
        p_can_maxima := -1; -- no esta definido el límite de cantidad
    END;
    
  begin
    --GDR-225
    v_bitacora := substr('paw_bce.fu_obt_limite:[1-Parametros-Entrada => p_cod_tip_mensaje='||p_cod_tip_mensaje || 
                                ', p_cod_persona='||p_cod_persona||  
                                ', p_nro_cuenta='||p_nro_cuenta||    
                                ', p_cod_moneda='||p_cod_moneda||   
                                ', p_cod_transaccion='||p_cod_transaccion||
                                ', p_cod_tra_padre='||p_cod_tra_padre||  
                                ', p_monto='||p_monto||        
                                ', p_modo='||p_modo||      
                                ', p_cod_ente='||p_cod_ente||     
                                ', p_session='||p_session||      
                                ', p_nro_ip='||p_nro_ip||     
                                ', p_cantidad='||p_cantidad||      
                                ', p_cod_per_vinculada='|| p_cod_per_vinculada ||'] ',1,4000);
                                
   
    -- si fu_obt_limite es llamado desde pag_ser, se utiliza bw_sesiones 
    -- para obtener el código de persona 
    v_cod_per_vinculada := p_cod_per_vinculada;
    
    
    if p_cod_tip_mensaje = '082' and p_cod_persona is null then
       BEGIN
          select a.cod_persona, a.cod_per_vinculada
            into v_cod_persona, v_cod_per_vinculada
            from bw_sesiones a
           where a.nro_sesion = p_session
             and a.nro_ip = p_nro_ip;
          
          -- si se logueo como empresa, se usa el código persona de la empresa
          -- VF: SE UTILIZA 
          /*if v_cod_per_vinculada is not null then
             v_cod_persona := v_cod_per_vinculada;
          end if;*/
            
       EXCEPTION 
          WHEN OTHERS THEN
             null;
       END;
    else
       v_cod_persona := p_cod_persona;
    end if;
  
  
    v_cod_per_control := NVL(v_cod_per_vinculada, v_cod_persona);

  
    BEGIN
       if pag_gen.FU_ES_PER_FISICA(v_cod_per_control) = 'S' then
          v_tip_persona := 'F';
       else
          v_tip_persona := 'J';
       end if;
    EXCEPTION
      WHEN OTHERS THEN
         paw_bce.v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
         v_cod_res := '-2';
    END;
    
    -- se agrega contador de operador de operaciones globales
    IF nvl(p_cantidad, 1) > 0 AND paw_bce.v_cod_respuesta = paw_bce.v_cod_aprobado THEN
       -- cuento los movimientos del día del cliente y la cuenta específica de la misma
       lp_obt_can_movimiento(p_cod_tip_mensaje, p_cod_ente, v_cod_per_control, p_nro_cuenta,
                             p_cod_transaccion, p_cod_tra_padre, v_can_tra_cuenta, v_can_tra_persona,v_tip_persona);
                             
       v_can_tra_cuenta  := v_can_tra_cuenta + nvl(p_cantidad, 1);
       v_can_tra_persona := v_can_tra_persona + nvl(p_cantidad, 1);
       
       -- buscamos el límite de cantidad por persona
       obt_lim_cantidad(v_cod_per_control, NULL, v_tip_persona, v_can_maxima);
       IF v_can_maxima < 0 THEN
          IF p_nro_cuenta IS NOT NULL THEN
             -- no existe límite de cantidad por persona, buscamos límite por cuenta
             obt_lim_cantidad(NULL, p_nro_cuenta, v_tip_persona, v_can_maxima);
          END IF;
          IF v_can_maxima < 0 THEN
             -- no existe límite de cantidad por persona ni cuenta, buscamos límite general
             obt_lim_cantidad(NULL, NULL, v_tip_persona, v_can_maxima);
             -- verificamos el limite general
             IF v_can_maxima < 0 THEN
                v_cod_respuesta := paw_bce.v_can_lim_indefinido;
                v_cod_res := -2; -- no existe límite de cantidad definido
             ELSE
                v_ctr_can_limite := 'G';
                v_can_max_limite := v_can_maxima;
                IF v_can_maxima < v_can_tra_persona THEN
                   v_cod_respuesta := paw_bce.v_can_lim_excedido;
                   v_cod_res := -1;
                END IF;
             END IF;
          ELSE -- controlamos el límite por cuenta
             v_ctr_can_limite := 'C';
             v_can_max_limite := v_can_maxima;
             IF v_can_maxima < v_can_tra_cuenta THEN
                v_cod_respuesta := paw_bce.v_can_lim_excedido;
                v_cod_res := -1;
             END IF;
          END IF;
       ELSE -- controlamos el límite por persona
          v_ctr_can_limite := 'P';
          v_can_max_limite := v_can_maxima;
          IF v_can_maxima < v_can_tra_persona THEN
             v_cod_respuesta := paw_bce.v_can_lim_excedido;
             v_cod_res := -1;
          END IF;
       END IF;
    END IF;
    
     --GDR-225
     v_bitacora := substr(v_bitacora || '[2-Ctrl-Limite-Cantidad => v_cod_per_control='||v_cod_per_control||
                                  ', p_cod_tip_mensaje='||p_cod_tip_mensaje|| 
                                  ', v_can_tra_cuenta='||v_can_tra_cuenta ||
                                  ', v_can_tra_persona='||v_can_tra_persona||
                                  ', v_ctr_can_limite(P/C/G)='||v_ctr_can_limite||
                                  ', v_can_max_limite='||v_can_max_limite||
                                  ', v_cod_respuesta='||v_cod_respuesta  ||
                                  ', v_cod_res='||v_cod_res||']' ,1,4000);
 
  
    IF paw_bce.v_cod_respuesta = paw_bce.v_cod_aprobado THEN
    
      -- guardo los movimientos del día del cliente y la cuenta específica de la misma
      pr_obt_tot_movimiento(p_cod_tip_mensaje, p_cod_ente, v_cod_per_control, p_nro_cuenta, p_cod_moneda,
                            p_cod_transaccion, p_cod_tra_padre, v_mto_tra_cuenta, v_mto_tra_persona,v_tip_persona);
                             
      v_mto_tra_cuenta  := v_mto_tra_cuenta + p_monto;
      v_mto_tra_persona := v_mto_tra_persona + p_monto;
      -- obtengo la consulta para devolver el mensaje
      v_existe := FALSE;
    
      BEGIN
         -- busco si hay definición de límite por persona
         FOR cur_per IN c_lim(p_cod_tip_mensaje, v_cod_per_control, NULL, v_tip_persona, p_cod_moneda) LOOP
            v_existe := TRUE;
            v_ctr_mto_limite := 'P'; --Persona
            v_mto_lim_minimo := cur_per.mto_minimo;
            v_mto_lim_maximo := cur_per.mto_maximo + 1;
            if cur_per.mto_minimo <= v_mto_tra_persona and v_mto_tra_persona <= cur_per.mto_maximo + 1 then
               v_combinaciones := v_combinaciones || cur_per.cod_tip_clave;
            end if;
         END LOOP;
         -- si no se encontró límite por persona, se busca límite por cuenta
         -- CR: se agrega control de p_nro_cuenta
         IF v_existe = FALSE AND p_nro_cuenta IS NOT NULL THEN
            FOR cur_cta IN c_lim(p_cod_tip_mensaje, NULL, p_nro_cuenta, v_tip_persona, p_cod_moneda) LOOP
               v_existe := TRUE;
               v_ctr_mto_limite := 'C';  --Cuenta
               v_mto_lim_minimo := cur_cta.mto_minimo;
               v_mto_lim_maximo := cur_cta.mto_maximo + 1;
               if cur_cta.mto_minimo <= v_mto_tra_cuenta and v_mto_tra_cuenta <= cur_cta.mto_maximo + 1 then
                  v_combinaciones := v_combinaciones || cur_cta.cod_tip_clave;
               end if;
            END LOOP;
         END IF;
         
          -- si no se encontró límite por persona ni por cuenta, se busca límite general
         IF v_existe = FALSE THEN
            FOR cur IN c_lim(p_cod_tip_mensaje, NULL, NULL, v_tip_persona, p_cod_moneda) LOOP
               v_existe := TRUE; 
               v_ctr_mto_limite := 'G';  -- General
               v_mto_lim_minimo := cur.mto_minimo;
               v_mto_lim_maximo := cur.mto_maximo + 1;
               if cur.mto_minimo <= v_mto_tra_persona and v_mto_tra_persona <= cur.mto_maximo + 1 then    
                  v_combinaciones := v_combinaciones || cur.cod_tip_clave;
               end if;                 
            END LOOP;
         END IF;
         
        
         if(Paw_Otp.fu_obtenerAsignacionSofttoken(v_cod_persona,v_tip_persona, v_cod_per_vinculada) is null) then
            v_obt_softToken:='N';
         else
           v_obt_softToken:='S';
           IF v_tip_persona = 'J' THEN
              return '02';
           END IF;
         end if;
          --GDR-225
          
          v_bitacora := substr(v_bitacora || '[3-Ctrl-Limite-Monto => v_cod_per_control='||v_cod_per_control||
                                     ', p_cod_tip_mensaje='||p_cod_tip_mensaje|| 
                                     ', v_mto_tra_cuenta='||v_mto_tra_cuenta || 
                                     ', v_mto_tra_persona='||v_mto_tra_persona||  
                                     ', v_ctr_mto_limite(P/C/G)='||v_ctr_mto_limite||
                                     ', v_mto_lim_minimo='||v_mto_lim_minimo||
                                     ', v_mto_lim_maximo='||v_mto_lim_maximo||
                                     ', v_combinaciones='||v_combinaciones||'] ',1,4000);
         
         --utpl
         IF v_existe = TRUE THEN
            case v_combinaciones 
               -- libre
               when 'L'   then v_cod_res := '00';
               when 'LL'  then v_cod_res := '00';
               when 'LLL' then v_cod_res := '00';
               -- solo clave transaccional
               when 'T'   then v_cod_res := '10';
               when 'TL'  then v_cod_res := '10';
               when 'LT'  then v_cod_res := '10';
               when 'TLL' then v_cod_res := '10';
               when 'LTL' then v_cod_res := '10';
               when 'LLT' then v_cod_res := '10';
               -- solo token
               when 'K'   then v_cod_res := '01';
               when 'KL'  then v_cod_res := '01';
               when 'LK'  then v_cod_res := '01';
               when 'LLK' then v_cod_res := '01';
               when 'LKL' then v_cod_res := '01';
               when 'KLL' then v_cod_res := '01';
               
               -- clave transaccional + token
               when 'TK'  then v_cod_res := '11';
               when 'KT'  then v_cod_res := '11';
               when 'KLT' then v_cod_res := '11';
               when 'KTL' then v_cod_res := '11';
               when 'TKL' then v_cod_res := '11';
               when 'TLK' then v_cod_res := '11';
               when 'LTK' then v_cod_res := '11';
               when 'LKT' then v_cod_res := '11';
               
               when 'S' then v_cod_res := '02';
               when 'SS' then v_cod_res := '02';               
               when 'SSS' then v_cod_res := '02';               

               when 'LS' then
                  if(v_obt_softToken='S') then
                     v_cod_res := '02';
                 else
                     v_cod_res := '00';
                 end if;  

               when 'SL' then 
                 if(v_obt_softToken='S') then
                     v_cod_res := '02';
                 else
                     v_cod_res := '00';
                 end if;   
               
               when 'KS' then --solo retornar un tipo de clave
                 if(v_obt_softToken='S') then
                     v_cod_res := '02';
                 else
                     v_cod_res := '01';
                 end if;
               when 'SK' then 
                 if(v_obt_softToken='S') then
                     v_cod_res := '02';
                 else
                     v_cod_res := '01';
                 end if;

               when 'TS' then 
                 if(v_obt_softToken='S') then
                     v_cod_res := '02';
                 else
                     v_cod_res := '10';
                 end if;
               when 'ST' then 
                 if(v_obt_softToken='S') then
                     v_cod_res := '02';
                 else
                     v_cod_res := '10';
                 end if;

               when 'KTS' then 
                 if(v_obt_softToken='S') then
                     v_cod_res := '02';
                 else
                     v_cod_res := '01';
                 end if;
               when 'KST' then 
                 if(v_obt_softToken='S') then
                     v_cod_res := '02';
                 else
                     v_cod_res := '01';
                 end if;
               when 'TKS' then 
                 if(v_obt_softToken='S') then
                     v_cod_res := '02';
                 else
                     v_cod_res := '01';
                 end if;
               when 'TSK' then 
                 if(v_obt_softToken='S') then
                     v_cod_res := '02';
                 else
                     v_cod_res := '01';
                 end if;
               when 'SKT' then 
                 if(v_obt_softToken='S') then
                     v_cod_res := '02';
                 else
                     v_cod_res := '01';
                 end if;
               when 'STK' then 
                 if(v_obt_softToken='S') then
                     v_cod_res := '02';
                 else
                     v_cod_res := '01';
                 end if;
               
               
                -- no posee autorización
               ELSE v_cod_res := '-1'; paw_bce.v_cod_respuesta := paw_bce.v_cla_lim_excedido;
            end case;
            -- verificacion de soft-token
            IF v_cod_res = '02' AND v_obt_softToken = 'N' THEN
               v_cod_res := '-2'; 
               paw_bce.v_cod_respuesta := paw_bce.v_cla_st_inexistente;
            END IF;
         ELSE -- límite no definido en bw_cla_lim_montos
            paw_bce.v_cod_respuesta := paw_bce.v_cla_lim_no_definido; 
            v_cod_res := '-3'; 
         END IF; -- (IF v_existe = TRUE)
      END; -- (FOR Cursores)
    END IF; -- (if paw_bce.v_cod_respuesta = paw_bce.v_cod_aprobado)
                            
    if v_cod_respuesta = paw_bce.v_cod_aprobado and v_cod_res in ('01','11') and fu_caj_homebanking(nvl(v_nro_terminal, '999')) = 'S' /*nvl(v_nro_terminal, '999') = '999'*/ then
       -- si es modo verificación, analizar si solicitar a VASCO enviar el challenge al usuario
       IF p_modo = 'V' OR (p_modo = 'L' AND p_cod_tip_mensaje in ('070','075','130')) THEN
          v_cod_respuesta := fu_obt_tok_validar(null, paw_bce.v_cod_persona, paw_bce.v_cod_per_empresa, 0, 'V');
          --DDSI-1513 Para control del retorno en Vasco 00 exitoso LADC - GDDF
          if v_cod_respuesta <> paw_bce.v_cod_aprobado then 
            v_cod_res := '-4';
          end if;
       END IF;
    end if;
    --GDR-225   
     v_bitacora := substr(v_bitacora ||'[4-Respuesta-Limite => v_cod_res='||v_cod_res ||
                                ', v_cod_respuesta='||v_cod_respuesta|| 
                                ', paw_bce.v_cod_aprobado='||paw_bce.v_cod_aprobado||
                                ', paw_bce.v_cod_respuesta='||paw_bce.v_cod_respuesta||'] ',1,4000);
                                
     paw_uti.pr_insertarBitacora(p_cod_persona,
                                '999',
                                p_session,
                                p_cod_tip_mensaje,
                                p_cod_per_vinculada,
                                v_bitacora,
                                paw_uti.BITACORA_SALIDA
                                );                                

 
    return v_cod_res;
  end;
--
function fu_val_cta_limite(p_nro_cuenta  IN ge_cuentas.nro_cuenta%TYPE,
                           p_tip_persona IN ba_personas.tipo%TYPE) -- F o J
  return varchar2 is 
  v_retorno VARCHAR2(1) := 'N';
begin
  select 'S'
    into v_retorno
    from ge_cta_clientes c, ba_personas p
   where c.nro_cuenta = p_nro_cuenta
     and c.relacion = 'P'
     and c.cod_persona = p.cod_persona
     and p.tipo = p_tip_persona;

  return v_retorno;
exception
  when others then
    return 'N';
end;

-- Función para saber que solicitar al autorizador (clave transaccional y/o token o nada).
function fu_obt_aut_limite(p_cod_empresa   in bw_mov_pendientes.cod_per_principal%type,
                           p_nro_documento in bw_mov_pendientes.nro_documento%type,
                           p_cod_persona in bw_mov_pendientes.cod_per_principal%type DEFAULT NULL)
  return varchar2 is
v_res_limite    varchar2(2);
v_tip_mensaje   bw_mov_pendientes.cod_tip_mensaje%type;
v_nro_cuenta    bw_mov_pendientes.nro_cuenta%type;
v_cod_moneda    bw_mov_pendientes.cod_moneda%type;
v_dato          bw_mov_pendientes.dato%type;
v_dato2          bw_mov_pendientes.dato2%type;
v_monto         bw_mov_pendientes.monto%type;
v_mto_cargo     bw_mov_pendientes.mto_cargo%type;
v_mto_contra    bw_mov_pendientes.mto_contra%type;
v_cod_tra_padre ge_movimientos.cod_tra_padre%type;
v_cod_ente      ge_entes.cod_ente%type;
v_lim_inferior  NUMBER:=0;
v_req_softoken  VARCHAR2(1) := 'N';

begin
   -- obtenemos los datos del movimiento pendiente
   SELECT cod_tip_mensaje, nro_cuenta, cod_moneda, dato,dato2, monto, nvl(mto_cargo, 0), mto_contra
     INTO v_tip_mensaje, v_nro_cuenta, v_cod_moneda, v_dato,v_dato2, v_monto, v_mto_cargo, v_mto_contra
     FROM bw_mov_pendientes
    WHERE nro_documento = p_nro_documento
      AND cod_per_principal = p_cod_empresa
      AND estado IN ('P', 'I');                 
         
   -- obtenemos la transacción padre de la operación donde se controla el límite
   CASE v_tip_mensaje
      WHEN '008' THEN
         v_req_softoken := 'S';
      WHEN '030' THEN -- transferencias a cuentas propias
         v_cod_ente      := null;
         v_cod_tra_padre := 388;
      WHEN '031' THEN -- pago de préstamos
         v_cod_ente      := null;
         v_cod_tra_padre := 360;
      WHEN '032' THEN -- pago de tarjetas de crédito
         v_cod_ente      := null;
         v_cod_tra_padre := 250;
      WHEN '033' THEN -- pagos aduaneros
         v_cod_ente      := null;
         v_cod_tra_padre := 219;
      WHEN '034' THEN -- pagos a la SET
         v_cod_ente      := null;
         v_cod_tra_padre := 487;
      WHEN '036' THEN -- transferencias interbancarias
         v_cod_ente      := null;
         v_cod_tra_padre := 303;
      WHEN '055' THEN  -- transf. a gnb
         v_cod_tra_padre := 411;
      WHEN '039' THEN -- transferencias a otros titulares
         v_cod_ente      := null;
         v_cod_tra_padre := 388;
      WHEN '082' THEN -- pago de servicios
         v_cod_ente      := null;
         v_cod_tra_padre := 485;
      WHEN '089' THEN -- pago de servicios
         v_cod_ente      := null;
         v_cod_tra_padre := 8526; --485;
         v_lim_inferior  := 1;
      WHEN '070' THEN -- pago de salarios
         v_cod_ente := to_number(trim(v_dato));
         v_cod_tra_padre := 303;
         v_lim_inferior := 1;
      WHEN '071' THEN -- acreditaciones gourmet
         v_cod_ente := to_number(trim(v_dato2));
         v_cod_tra_padre := 5166;
      WHEN '075' THEN -- pago proveedores
         v_cod_ente := to_number(trim(v_dato));
         v_cod_tra_padre := fug_obt_parentes(v_cod_ente, 'COD_TRA_PAD_PPROV');
         v_lim_inferior:=1;
      WHEN '130' THEN -- alta empleados
         v_cod_tra_padre := null; -- no genera movimientos
         v_lim_inferior  := 1;
      WHEN '150' THEN -- actualizacion token digital
         v_cod_tra_padre := null; -- no genera movimientos
         v_lim_inferior  := 1;
         v_cod_moneda    := v_cod_mon_local;
      WHEN '214' THEN -- transferencias de cambio pre-pactadas
         v_cod_ente      := null;
         v_cod_tra_padre := 388;
      WHEN '227' THEN -- transferencias internacionales
         v_cod_ente := null;
         IF v_cod_moneda = v_cod_mon_local THEN
            v_cod_tra_padre := 264; -- venta transferencia
         ELSE
            IF v_mto_contra = (v_monto - v_mto_cargo) THEN
               v_cod_tra_padre := 288; -- canje extraccion
            ELSE
               v_cod_tra_padre := 255; -- compra extraccion
            END IF;
         END IF;
      ELSE                                    
         v_cod_tra_padre := -1; -- no es una operación que controla límite
   end case;
   
   if v_req_softoken = 'S' then
     v_res_limite := '02';
   elsif v_cod_tra_padre = -1 then
      v_res_limite := '00';
   else
      v_res_limite := fu_obt_limite(v_tip_mensaje,
                                    p_cod_persona,
                                    v_nro_cuenta,
                                    v_cod_moneda,
                                    503,
                                    v_cod_tra_padre,
                                    v_lim_inferior,
                                    'A',
                                    v_cod_ente,
                                    null,
                                    null,
                                    0,
                                    p_cod_empresa);
   end if;
   
   return v_res_limite; 
exception
  when no_data_found then
    paw_bce.v_cod_respuesta := paw_bce.v_cod_ped_duplicado;
    return '00';
  when others then
    paw_bce.v_cod_respuesta := paw_bce.v_cod_cta_sin_mov;
    return '00';
end;

-- Verifica que una transacción igual no se haya realizado en los últimos minutos
function fu_ver_transaccion(p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE,
                            p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE,
                            p_nro_cuenta      IN ge_movimientos.nro_cuenta%TYPE,
                            p_monto           IN ge_movimientos.monto%TYPE) 
  return varchar2 is
v_existe    varchar2(1);
begin
   lp_ver_horario;
   begin
      if v_es_mov_noc = 'S' then
         select 'S'
           into v_existe
           from ge_movimientos_noc
          where nro_cuenta = p_nro_cuenta
            and cod_transaccion = p_cod_transaccion
            and cod_tra_padre = p_cod_tra_padre
            and monto = p_monto
            and reversado = 'N'
            and cod_usuario = v_cod_usuario
            and ((sysdate) -fec_insercion)*1440 <= v_min_transaccion
            and rownum = 1;
      else
         select 'S'
           into v_existe
           from ge_movimientos
          where nro_cuenta = p_nro_cuenta
            and cod_transaccion = p_cod_transaccion
            and cod_tra_padre = p_cod_tra_padre
            and monto = p_monto
            and reversado = 'N'
            and cod_usuario = v_cod_usuario
            and ((sysdate) -fec_insercion)*1440 <= v_min_transaccion
            and rownum = 1;
      end if;
   exception
     when no_data_found then
       v_existe := 'N';
     when too_many_rows then
       v_existe := 'S';
   end;
   
   return v_existe;
end;

-- Verifica si ya existe el movimiento pendiente
function fu_ver_mov_pendiente(p_cod_per_empresa in bw_mov_pendientes.cod_per_principal%type,
                              p_nro_cta_debito  in bw_mov_pendientes.nro_cuenta%type,
                              p_nro_cta_credito in bw_mov_pendientes.nro_cuenta%type,
                              p_monto           in bw_mov_pendientes.monto%type,
                              p_cod_tip_mensaje in bw_mov_pendientes.cod_tip_mensaje%type)
  return varchar2 is
v_existe varchar2(1);
begin
  begin
    select 'S'
      into v_existe
      from bw_mov_pendientes
     where cod_per_principal = p_cod_per_empresa
       and nro_cuenta = p_nro_cta_debito
       and monto = p_monto
       and estado = 'P'
       and cod_tip_mensaje = p_cod_tip_mensaje
       and nro_cta_contra = p_nro_cta_credito
       and rownum = 1;
  exception
    when too_many_rows then
      v_existe := 'S';
    when others then
      v_existe := 'N';
    end;
  return v_existe;
end;

/*VALIDA LA DUPLICACION DEL MOVIMIENTO*/
procedure pr_val_duplicacion(p_nro_cta_debito in varchar2,
                             p_mto_debito     in number,
                             p_dato           in varchar2,
                             p_cod_tra_padre  in number) is
v_existe varchar2(1) := 'S';
begin
   begin
      select 'S'
        into v_existe
      from bw_mov_pendientes
      where cod_per_principal = v_cod_per_empresa
        and nro_cuenta = p_nro_cta_debito
        and monto = p_mto_debito
        and estado = 'P'
        and cod_tip_mensaje = '036'
        and dato = p_dato
        and can_aut_faltantes > 0
        and ((sysdate) -fec_insercion)*24*60 <=10
        and rownum = 1;
    exception
       when too_many_rows then
          v_existe := 'S';
       when others then
          v_existe := 'N';
    end;
    if v_existe = 'N' then
      if v_es_mov_noc = 'S' then
         select distinct 'S'
           into v_existe
           from ge_movimientos_noc
          where nro_cuenta = p_nro_cta_debito
            and cod_tra_padre = p_cod_tra_padre
            and monto = p_mto_debito
            and reversado = 'N'
            and nro_secuencia = '1'
            and cod_usuario = v_cod_usuario
            -- Controla que por lo menos haya pasado 10 minutos
            and ((sysdate) -fec_insercion)*24*60 <=10
            and rownum = 1;
      else
         select distinct 'S'
           into v_existe
           from ge_movimientos
          where nro_cuenta = p_nro_cta_debito
            and cod_tra_padre = p_cod_tra_padre
            and monto = p_mto_debito
            and reversado = 'N'
            and nro_secuencia = '1'
            and cod_usuario = v_cod_usuario
            and fecha = v_fec_actual
            -- Controla que por lo menos haya pasado 10 minutos
            and ((sysdate) -fec_insercion)*24*60 <=10
            and rownum = 1;
       end if;
    end if;
    if nvl(v_existe,'N') = 'S' then
       v_cod_respuesta := v_cod_mov_ya_ingresado;
    end if ;
exception
   when no_data_found then
      null;
   when too_many_rows then
      v_cod_respuesta := v_cod_mov_ya_ingresado;
end;

procedure pr_ver_cta_aguinaldo(p_nro_cuenta    in ge_cuentas.nro_cuenta%type,
                               p_traspaso      in varchar2,
                               p_cod_error     in out number,
                               p_mensaje       in out varchar2,
                               p_longitud      in number) is
   v_existe   varchar2(1) := 'N';      
begin      
   if p_traspaso = 'N' then
      v_existe := 'S';
   else
      --obtener la cuenta de caja de ahorro para aguinaldo
      begin
         select 'S'
           into v_existe
           from ah_cta_vistas v, ge_cta_clientes ca
           inner join ge_cuentas ce_ge
           on ce_ge.nro_cuenta=ca.nro_cuenta
          where v.nro_cuenta = p_nro_cuenta
            and ca.nro_cuenta = v.nro_cuenta
            and ca.relacion = 'P'
            and v.estado not in ('X', 'C', 'P')
            and v.cod_sub_modalidad = 6
            and ce_ge.cod_moneda = v.cod_moneda;
      exception
         when no_data_found then
            v_existe := 'N'; -- no existe
         when too_many_rows then
            v_existe := 'T'; -- cuenta duplicada
         when others then
            v_existe := 'O'; -- otro error
      end;
   end if;
   if v_existe = 'N' and p_traspaso = 'S' then
      -- buscar una cuenta a traves de su cc
      begin
         select 'S'
           into v_existe
           from ah_cta_vistas v, ge_cta_clientes ca, ge_cta_clientes cl, cc_cta_corrientes cc
          where cc.nro_cuenta = p_nro_cuenta
            and cl.nro_cuenta = cc.nro_cuenta
            and cl.relacion = 'P'
            and ca.nro_cuenta = v.nro_cuenta
            and ca.relacion = 'P'
            and ca.cod_persona = cl.cod_persona
            and v.estado not in ('X', 'C', 'P')
            and v.cod_sub_modalidad = 6
            and v.cod_moneda = cc.cod_moneda;
      exception
         when no_data_found then
            v_existe := 'N'; -- no existe
         when too_many_rows then
            v_existe := 'T'; -- cta duplicada
         when others then
            v_existe := 'O'; -- otro error
      end;
   end if;
   if v_existe = 'N' and p_traspaso = 'S' then
      -- buscar una cuenta a traves de su ah
      begin
         select 'S'
           into v_existe
           from ah_cta_vistas v, ge_cta_clientes ca, ge_cta_clientes cl, ah_cta_vistas cc, ge_cuentas ge
          where cc.nro_cuenta = p_nro_cuenta
            and cl.nro_cuenta = cc.nro_cuenta
            and cl.relacion = 'P'
            and v.nro_cuenta <> p_nro_cuenta
            and ca.nro_cuenta = v.nro_cuenta
            and ca.relacion = 'P'
            and ca.cod_persona = cl.cod_persona
            and v.estado not in ('X', 'C', 'P')
            and v.cod_sub_modalidad = 6
            and ge.nro_cuenta = p_nro_cuenta
            and v.cod_moneda = ge.cod_moneda;
      exception
         when no_data_found then
            v_existe := 'N'; -- no existe
         when too_many_rows then
            v_existe := 'T'; -- cta duplicada
         when others then
            v_existe := 'O'; -- otro error
      end;
   end if;
  
   if v_existe = 'N' then
      p_mensaje := substr('cta. aguinaldo inexistente', 1, p_longitud);
   elsif v_existe = 'T' then
      p_mensaje := substr('cta. aguinaldo duplicada', 1, p_longitud);
   elsif v_existe <> 'S' then
      p_mensaje := substr('cta. aguinaldo invalida', 1, p_longitud);
   end if;

   if v_existe <> 'S' then
      p_cod_error := p_cod_error + 1;
   end if;
end;


Function fu_inh_lim_cliente(p_cod_cliente     IN ba_personas.cod_persona%TYPE,
                            p_cod_canal            IN VARCHAR2 DEFAULT NULL,
                            p_identificador_sesion IN VARCHAR2 DEFAULT NULL) return NUMBER IS
    v_tip_persona       bw_cla_lim_montos.tip_persona%TYPE;
    v_cod_persona       ba_personas.cod_persona%TYPE := NULL;
    v_cod_empresa       ba_personas.cod_persona%TYPE := NULL;
    v_afectados         NUMBER;
BEGIN

   BEGIN
       if pag_gen.FU_ES_PER_FISICA(p_cod_cliente) = 'S' then
          v_tip_persona := 'F';
          v_cod_persona := p_cod_cliente;
       else
          v_tip_persona := 'J';
          v_cod_empresa := p_cod_cliente;
       end if;
    EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_insertarBitacora(v_cod_persona,
                                p_cod_canal,
                                p_identificador_sesion,
                                null,
                                v_cod_empresa,
                                'fu_inh_lim_cliente: [p_cod_cliente=' || p_cod_cliente || '] Cliente no existe',
                                paw_uti.BITACORA_ERROR);
        return -1;
    END;

    paw_uti.pr_insertarBitacora(v_cod_persona,
                                p_cod_canal,
                                p_identificador_sesion,
                                null,
                                v_cod_empresa,
                                'fu_inh_lim_cliente: [p_cod_persona=' || v_cod_persona || '] se verificara si el cliente cuenta con limites personalizados' ,
                                paw_uti.BITACORA_ENTRADA);
 
    
    
    UPDATE bw_cla_lim_montos bclm
    SET bclm.activo = 'I'
    WHERE bclm.tip_persona = v_tip_persona
       AND bclm.activo = 'A'
       AND bclm.cod_persona = p_cod_cliente
       --AND bclm.cod_tip_clave in ('K', 'T','L'); --- DDEVOLUT-1296- 
       AND bclm.cod_tip_clave in ('K', 'T');
    v_afectados := SQL%rowcount; 
       
    paw_uti.pr_insertarBitacora(v_cod_persona,
                                p_cod_canal,
                                p_identificador_sesion,
                                null,
                                v_cod_empresa,
                                'fu_inh_lim_cliente:  [p_cod_persona=' || v_cod_persona || '] se inhabilitarosn [' ||  v_afectados || '] registros. ' 
                                    || paw_uti.fu_generarBitacora(null ,null, null ,null),
                                paw_uti.BITACORA_SALIDA);
   return v_afectados;                                 
                                    
EXCEPTION
    WHEN OTHERS THEN
        paw_uti.pr_insertarBitacora(v_cod_persona,
                                p_cod_canal,
                                p_identificador_sesion,
                                null,
                                v_cod_empresa,
                                'fu_inh_lim_cliente: [p_cod_cliente=' || p_cod_cliente || '] : ERROR: ['|| sqlcode ||']',
                                paw_uti.BITACORA_ERROR);
        return -1;
END;

----------------********** OPERACIONES PARTICULARES **********------------------------
-- Sincronización. Devuelve la fecha y hora
function fu_pro_operacion_000(p_parametros in varchar2)
  return varchar2 is
begin
  -- Retorna la fecha y hora en el formato:
  -- FECHA  Fecha del Servidor: formato ddmmyyyy    D  8
  -- HORA  Hora del Servidor: formato hhmmss          C  8
   return to_char(sysdate,'ddmmyyyyhh24miss');
end;
-- fin de la sincronización

-- Identificación del cliente. Devuelve datos del cliente
function fu_pro_operacion_005(p_parametros in varchar2)
  return varchar2 is
-- datos a responder
v_nom_oficial  varchar2(50);  -- nombre del oficial del cliente
v_tel_oficial  varchar2(10);  -- teléfono del oficial
v_cor_oficial  varchar2(80);  -- correo email del oficial
v_dir_ip       varchar2(20);
v_observacion  varchar2(1000);
v_nom_perfil   varchar2(35);
v_vip          varchar2(1);
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. cargo los datos del oficial, si es valido
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     begin
        select substr(nvl(u.nombre,' '),1,50),
               substr(nvl(u.telefono,'4176000'),1,10),
               nvl(u.dir_correo, fug_obt_dir_correo) dir_correo
          into v_nom_oficial, v_tel_oficial, v_cor_oficial
          from ba_usuarios u
         where cod_usuario = v_cod_usu_oficial;
     exception
        when others then
           v_cod_respuesta  := paw_bce.v_cod_otr_error;
     end;
  end if;
  If length(p_parametros) > 66 then
     v_dir_ip := replace(trim(substr(p_parametros, 66, length(p_parametros)-65)), chr(13),'');
     If v_dir_ip is not null then
       -- registro del movimiento
       lp_reg_operacion(null /*p_nro_cuenta*/,
                        null /*p_cod_moneda */,
                        null /*p_monto*/,
                        null /*p_nro_cta_contra*/,
                        null /*p_cantidad*/,
                        'Tipo Acceso' /*p_etiqueta*/,
                        nvl(trim(substr(p_parametros,49,1)),'C') /*p_dato*/,
                        'Dato' /*p_etiqueta2*/,
                        trim(substr(p_parametros,33,16)) /*p_dato2*/,
                        null /*p_observacion*/,
                        v_dir_ip /* p_dir_ip*/
                       );
     end if;
  End if;
  begin
    select descripcion
      into v_nom_perfil
      from bw_perfiles
     where cod_perfil = v_cod_perfil;
  exception
    when others then
       v_nom_perfil := 'Sin Perfil asignado';
  end;
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     v_vip:=fu_es_vip(v_cod_persona);
     return v_cam_clave||
            lf_for_char(nvl(v_nom_empresa,v_nom_completo),100)||
            lf_for_char(v_nom_oficial,50)||
            lf_for_char(v_tel_oficial,10)||
            lf_for_char(v_cor_oficial,80)||
            lf_for_char(lf_obt_mensaje(nvl(v_cod_per_empresa,v_cod_persona)),300)||
            lf_for_char(v_cod_persona,10)||
            lf_for_char(v_nom_perfil,35)||
            lf_for_char(v_cod_per_empresa,10)||
            lf_for_char(v_nom_completo,100)||
            lf_for_char(v_vip,1);
  else
     return null;  -- nada
  end if;
end;
--- fin de la identificacion del cliente

-- Validacion de cuentas/tarjetas para depositos o pagos con o sin clave
function fu_pro_operacion_010(p_parametros in varchar2)
  return varchar2 is
-- datos recibidos
v_tip_consulta   varchar2(3) := substr(p_parametros,66,3);   -- tipo de consulta
-- datos a responder
v_nro_cuenta     varchar2(17);  -- numero de cuenta
v_cta_formateada varchar2(17);  -- cuenta formateada
v_cod_tip_cuenta varchar2(2);   -- codigo del tipo de cuenta
v_des_tip_cuenta varchar2(35);  -- descripcion del tipo de cuenta
v_cod_moneda     varchar2(3);   -- moneda de la cuenta
v_nom_cuenta     varchar2(100); -- nombre de la cuenta
v_nom_oficial    varchar2(50);  -- nombre del oficial del cliente
v_tel_oficial    varchar2(10);  -- telefono del oficial
v_cor_oficial    varchar2(80);  -- correo email del oficial
-- variables
v_est_cuenta     varchar2(1);   -- estado de la cuenta
v_cod_mod_cta    number(4);     -- modulo de la cuenta
v_cod_mad_cta    number(4);     -- modalidad de la cuenta
v_cod_sub_mad_cta number(4);    -- sub modalidad de la cuenta
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. cargo los datos del oficial, si es valido
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     begin
         select substr(u.nombre,1,50), substr(u.telefono,1,10), u.dir_correo
          into v_nom_oficial, v_tel_oficial, v_cor_oficial
          from ba_usuarios u
         where cod_usuario = v_cod_usu_oficial;
     exception
        when others then
           v_cod_respuesta  := paw_bce.v_cod_otr_error;
     end;
  end if;
  -- 3. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     begin
        select a.nro_cuenta,
               fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina,a.nro_cuenta, a.cod_moneda),
               fu_tip_cuenta(a.cod_modulo, a.cod_modalidad),
               fug_obt_des_modal(a.cod_modulo,a.cod_modalidad),
               a.cod_moneda, a.denominacion, a.estado, cod_modalidad,
               cod_modulo, cod_sub_modalidad
          into v_nro_cuenta,v_cta_formateada, v_cod_tip_cuenta,
               v_des_tip_cuenta, v_cod_moneda, v_nom_cuenta,
               v_est_cuenta, v_cod_mad_cta, v_cod_mod_cta, v_cod_sub_mad_cta
          from ge_cuentas a
         where a.nro_cuenta = p_dato; -- contiene el nro de cuenta
      -- v_tip_consulta: 015=Deposito, 031=Prestamos, 032=Tarjetas
      if v_cod_mod_cta = 5 then
         v_cta_formateada := lf_obt_nro_tarjeta(v_nro_cuenta);
      end if;
      if v_tip_consulta = '015' then
         -- deposito
         if v_cod_mad_cta not in (31,41) then
            v_cod_respuesta := paw_bce.v_cod_cta_invalida;
         elsif v_est_cuenta not in ('A','I','N','S') then
            v_cod_respuesta := paw_bce.v_cod_cta_invalida;
         elsif pag_cta.fu_ver_tra_prohibida(v_nro_cuenta,393, 9, 91) = 'S' then
            v_cod_respuesta := paw_bce.v_cod_tra_prohibida;
         elsif v_cod_mad_cta = 31 and v_cod_sub_mad_cta = 26 then -- Cuenta Basica
            v_cod_respuesta := paw_bce.v_cod_tra_prohibida;
         --elsif v_cod_mad_cta = 31  and pag_cta.fu_obt_cta_cte_comb(p_dato) is not null then
         --   v_cod_respuesta := paw_bce.v_cod_cta_invalida;
         end if;
      elsif v_tip_consulta = '031' then
         -- pago de prestamos
         if v_cod_mod_cta <> 6 then
            v_cod_respuesta := paw_bce.v_cod_cta_invalida;
         elsif v_est_cuenta in ('N') then -- cancelada
            v_cod_respuesta := paw_bce.v_cod_cta_cancelada;
         end if;
      elsif v_tip_consulta = '032' then
         -- pago de tarjetas
         if v_cod_mod_cta <> 5 then
            v_cod_respuesta := paw_bce.v_cod_cta_invalida;
         elsif v_est_cuenta in ('C') then -- cancelada
            v_cod_respuesta := paw_bce.v_cod_cta_cancelada;
         end if;
      end if;

     exception
        when no_data_found then
           v_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
        when too_many_rows then
           v_cod_respuesta  := paw_bce.v_cod_cta_duplicada;
        when others then
           v_cod_respuesta  := paw_bce.v_cod_cta_invalida;
     end;
  end if;
  -- registro del movimiento
  lp_reg_operacion(v_nro_cuenta /*p_nro_cuenta*/,
                   v_cod_moneda /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Tipo Consulta' /*p_etiqueta*/,
                   v_tip_consulta /*p_dato*/
                 );
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return lf_for_char(v_cta_formateada,17)||
            lf_for_char(v_cod_tip_cuenta,2)||
            lf_for_char(v_des_tip_cuenta,35)||
            lf_for_char(rpad(v_cod_moneda,3,'.'),3)||
            lf_for_char(v_nom_cuenta,100)||
            lf_for_char(v_nom_oficial,50)||
            lf_for_char(v_tel_oficial,10)||
            lf_for_char(nvl(v_cor_oficial,'.'),80);
  else
     return null;  -- nada
  end if;
end;
-- fin de 010-validacion de cuentas o tarjetas

-- Devuelve las cuentas del cliente
function fu_pro_operacion_011(p_parametros in varchar2,
                              p_ver_cuentas in varchar2 default null,
                              p_cod_moneda  in varchar2 default null,
                              p_tip_consulta in varchar2 default null)
  return clob is
-- datos recibidos
v_tip_consulta   varchar2(3) := substr(p_parametros,66,3);   -- tipo de consulta
v_ver_cuentas    varchar2(1) := substr(p_parametros,69,1);   -- ver solo cuentas de debito, credito o todas
-- datos a responder
v_can_detalles   number(3);     -- cantidad de cuentas
--
v_detalles       clob := null; -- datos de las cuentas
v_despliega      varchar2(1);  -- indica si la cuenta debe o no desplegarse
v_mon_cta        varchar2(3);  -- codigo de moneda para el cursor de detalle
v_cta_formateada varchar2(17); -- para guardar la cuenta formateada
-- cursor de cuentas del cliente
cursor cuentas is
  select a.nro_cuenta, a.cod_modalidad cod_modalidad,
         fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina,a.nro_cuenta, a.cod_moneda) cta_formateada,
         fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta,
         fug_obt_des_modal(a.cod_modulo,a.cod_modalidad) des_tip_cuenta,
         a.cod_moneda cod_moneda, a.denominacion nom_cuenta,
         fu_obt_sal_actual(a.cod_modulo, a.cod_modalidad, a.nro_cuenta) sal_actual,
         a.cod_modulo, a.estado
    from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
   where a.nro_cuenta = b.nro_cuenta
     and b.relacion in ('O','P','Y')
     and b.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
     and a.cod_modulo = c.cod_modulo
     and a.cod_modalidad = c.cod_modalidad
     and a.estado = c.estado
     and b.cod_modulo != 7
     and b.cod_modalidad <> 36
     and ((a.cod_modulo = 6 and nvl(fup_obt_tip_descuento(a.cod_modalidad),'x') not in ('F','D','C')) or a.cod_modulo <> 6) --para que no traiga las modalidades de descuento de cheques y documentos
     and c.activo = 'S'  -- solo cuentas activas
     and a.estado <> 'X' -- pendiente de verificacion
     and (p_cod_moneda is null or a.cod_moneda = p_cod_moneda)
   order by decode(b.cod_modalidad,31,1,
                   decode(b.cod_modulo,5,2,
                          decode(b.cod_modalidad,33,4,34,4,36,4,
                                 decode(b.cod_modulo,4,3,7))));
Cursor entes is  -- OMM 11/01/2011
     select a.cod_ente, fug_obt_parentes(a.cod_ente,'NRO_CTA_DEBITO') Cta_debito
      from ge_entes a
     where a.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
       and a.tipo = 'SU'
       and fug_obt_parentes(a.cod_ente,'SER_ACTIVO') = 'S'
       and fug_obt_parentes(a.cod_ente,'HAB_HOMEBANKING') = 'S' ;

Cursor ctas_entes (p_cod_ente number, p_moneda varchar2) is
      -- Se utiliza para validar pago de Sueldos
      select distinct a.cod_ente, g.cod_moneda, g.nro_cuenta,
              decode(g.cod_modalidad, 31, 'AH', 'CC') Tipo_cta, g.denominacion
      from ge_entes a, ge_cta_clientes c, ge_cuentas g
      where a.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
       and a.tipo = 'SU'
       and fug_obt_parentes(a.cod_ente,'SER_ACTIVO') = 'S'
       and fug_obt_parentes(a.cod_ente,'HAB_HOMEBANKING') = 'S'
       and a.cod_ente = p_cod_ente
       and a.cod_persona = c.cod_persona
       and c.relacion = 'P'
       and c.nro_cuenta = g.nro_cuenta
       and g.cod_modalidad in (31, 41)
       and g.estado IN ('N', 'S')
       and g.cod_moneda = p_moneda
       order by g.cod_moneda, Tipo_cta, g.nro_cuenta ;
-- se utiliza para desplegar las cuentas débito para pago a proveedores
cursor ctas_provee(p_cod_ente        ge_entes.cod_ente%type,
                   p_cod_per_empresa ge_clientes.cod_persona%type) is  
  select c.cod_moneda cod_moneda, trim(a.val_parametro) nro_cuenta
    from ge_par_entes a, ge_cuentas c, ge_cta_clientes b
   where a.cod_ente = p_cod_ente
     and b.cod_persona = p_cod_per_empresa
     and c.cod_modulo in (3,4)
     and c.cod_modalidad in (31,41)
     and c.nro_cuenta = trim(a.val_parametro)
     and c.nro_cuenta = b.nro_cuenta
     and c.cod_moneda in (pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_FUERTE)
     and a.parametro like 'CTA_DEB_PPROV%'
     and c.estado not in ('X','C','P')
     and a.val_parametro is not null;
begin
  if p_ver_cuentas is not null then
     -- viene como cuentas de debito directo
     v_ver_cuentas := p_ver_cuentas;
  else
     -- 1. valido la clave del cliente
     pr_val_clave(p_parametros);
  end if;
  if p_tip_consulta is not null then
     v_tip_consulta := p_tip_consulta;
  end if;

  -- Verifico si el cliente con su perfil tendrá acceso a realizar la transaccion
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, v_tip_consulta);
     if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
        if v_ver_cuentas = 'D' then
           v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
        end if;
     end if;
  end if;

  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     v_can_detalles := 0;
     for ct in cuentas loop
        v_despliega := 'N';
        if v_ver_cuentas = 'T' then
           -- quiere ver todas las cuentas
           if (substr(v_tip_consulta,1,2) = '06' and ct.cod_modalidad = 41) then -- consulta de chequeras
              v_despliega := 'S'; -- cuentas corrientes por chequeras
           elsif (v_tip_consulta in ('021','040','041') and ct.cod_modalidad in (31,41)) then
              v_despliega := 'S'; -- cuentas ahorro o ctacte y es consulta de mov, cheq, dev o depositos pendientes
           elsif (v_tip_consulta in ('020')) then -- consulta de saldos general
              v_despliega := 'S';
           elsif (v_tip_consulta in ('070')) then -- Pago de Sueldos.
               begin
                  select count(*)
                    into v_can_detalles
                    from ge_entes a
                   where a.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
                     and a.tipo = 'SU'
                     and fug_obt_parentes(a.cod_ente,'SER_ACTIVO') = 'S'
                     and fug_obt_parentes(a.cod_ente,'HAB_HOMEBANKING') = 'S';
                  v_despliega := 'N';
                  -- Si existe verifico cuantas cuentas posee.
                  If v_can_detalles > 0 then
                      v_can_detalles := 0 ;
                     for et in entes loop
                         v_mon_cta := fug_obt_mon_cta(et.cta_debito) ;
                         -- agregado para utilizar la cuenta debito por defecto en el despliege
                         -- v_detalles :=  v_detalles||lf_for_char(et.cta_debito, 15);
                         for ce in ctas_entes (et.cod_ente, v_mon_cta) loop
                             v_detalles :=  v_detalles||lf_for_char(et.cta_debito, 15);
                             v_can_detalles := v_can_detalles +1;
                             v_detalles :=  v_detalles ||
                             lf_for_char(ce.cod_ente,5)||
                             lf_for_char(ce.cod_moneda,3)||
                             lf_for_char(ce.nro_cuenta,15)||
                             lf_for_char(ce.tipo_cta,2)||
                             lf_for_char(ce.denominacion,70);
                          end loop;
                     end loop;
                  else
                     v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
                  end if;
               exception
                  when too_many_rows then
                      v_cod_respuesta := paw_bce.v_cod_cta_duplicada;
                  when others then
                      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
               end;
           elsif (v_tip_consulta in ('075')) then -- Pago a Proveedores
              declare
                 v_cod_ente       ge_entes.cod_ente%type;
              begin                 
                 -- Se utiliza para validar pago a proveedores
                 select cod_ente
                   into v_cod_ente
                   from ge_entes a
                  where a.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
                    and a.tipo = 'PR'
                    and fug_obt_parentes(a.cod_ente,'SER_ACTIVO_PRV') = 'S'
                    and fug_obt_parentes(a.cod_ente,'HAB_HOMEBANKING_PRV') = 'S';
                                     
                  v_despliega := 'N';
                  v_can_detalles := 0;
                  
                  -- agregamos la hora de cierre y el código del ente                
                  v_detalles := v_detalles||nvl(substr(trim(fug_obt_pardinamico('HOR_CIE_PROVEEDOR_HB')),1,5), '14:30')
                                          ||lf_for_char(v_cod_ente,5);                    
                  -- se arma el detalle de cuentas                    
                  for cp in ctas_provee(v_cod_ente, nvl(v_cod_per_empresa, v_cod_persona)) loop
                    v_can_detalles := v_can_detalles + 1;
                    v_detalles := v_detalles||lf_for_char(cp.cod_moneda,3)
                                            ||lf_for_char(cp.nro_cuenta,15);
                  end loop;
                  if v_can_detalles = 0 then
                    v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
                  end if; 
              exception
                 when too_many_rows then
                    v_cod_respuesta := paw_bce.v_cod_cta_duplicada;
                 when others then
                    v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
              end;
           end if;
        elsif (v_ver_cuentas in ('D','C') and ct.cod_modalidad in (31,41)) then
           -- OMM 03/02/2011 -- Para evitar mostrar monedas distintas a GS en Pago de Salarios
           if v_tip_consulta = '087' and ct.cod_moneda <> v_cod_mon_local then
                v_despliega := 'N';
            else
               if ct.cod_modalidad = 31 and pag_cta.fu_obt_cta_cte_comb(ct.nro_cuenta) is not null then
                  -- Cuentas de ahorro conjuntas no se deben desplegar para débito
                  if v_ver_cuentas = 'D' and fu_es_conjunta(ct.nro_cuenta) = 'S' then
                     v_despliega := 'N';
                  else
                     v_despliega := 'S';
                  end if;
               else
                   if v_ver_cuentas = 'D' then
                      -- veo si la cuenta no es conjunta
                      if fu_es_conjunta(ct.nro_cuenta) = 'S' or ct.estado in ('X','A','T','D','C','V','P','B') then
                         v_despliega := 'N';
                      else
                         v_despliega := 'S';
                      end if;

                   else
                     -- OMM 20/10/2010 Se agrego condicion para no mostrar cuentas inactivas
                     if ct.estado in ('X','T','D','C','V','P','B') then
                         v_despliega := 'N';
                      else
                         v_despliega := 'S';
                      end if;
                   end if;
               end if;
           end if ;
        elsif v_tip_consulta in ('031', '032') and v_ver_cuentas not in ('D') then
           if v_tip_consulta = '032' then -- pago de tarjetas
              if  ct.cod_modulo = 5  then
                  v_despliega := 'S';
              end if;
              -- TJ Gourmet no se debe listar para pagos, si para extractos
              if ct.cod_modulo = 5 and ct.cod_modalidad=55 then
                if v_ver_cuentas <> 'G' then
                   v_despliega := 'N';
                end if;
              end if;
           elsif v_tip_consulta = '031' then -- pago de prestamos
              if ct.cod_modulo = 6 then
                 v_despliega := 'S';
              end if;
           end if;
        end if;
        --- Debe controlar para que no muestre cuentas juridicas entre las cuentas del cliente
        If fu_es_juridica(ct.nro_cuenta) = 'S' and v_despliega = 'S' then
           v_despliega := 'N';
        End if;

        ---
        if v_despliega = 'S' then  -- solo si se muestra
             if ct.cod_modulo = 5 then
               v_cta_formateada := lf_obt_nro_tarjeta(ct.nro_cuenta);
             else
               v_cta_formateada := ct.cta_formateada;
             end if;
             v_can_detalles := v_can_detalles + 1;
             v_detalles :=  v_detalles ||
                            lf_for_char(v_cta_formateada,17)||
                            lf_for_char(ct.cod_tip_cuenta,2)||
                            lf_for_char(ct.des_tip_cuenta,35)||
                            lf_for_char(ct.nom_cuenta,50)||
                            lf_for_char(rpad(ct.cod_moneda,3,'.'),3)||
                            lf_for_money(ct.sal_actual);
        end if;
        if (v_tip_consulta in ('070', '075')) then -- Pago de Sueldos y Pago de Proveedores...
           Exit;
        End if;
     end loop;
     if v_can_detalles = 0 and nvl(p_tip_consulta,'k') not in ('031','032') and v_tip_consulta not in ('030','070','075') then
        -- no tiene cotizaciones
         v_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
     end if;
  end if;
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return lf_for_number(v_can_detalles,3)||
            v_detalles;
  else
     return null;  -- nada
  end if;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 011 cuentas del cliente


-- 015-confirmacion del deposito en cuenta
function fu_pro_operacion_015(p_parametros in varchar2)
  return varchar2 is
-- datos recibidos
v_nro_sobre       number(10);  --   := to_number(trim(substr(p_parametros,66,10)));   -- sobre
v_imp_efectivo    number(18,2) := 0;   -- efectivo
v_imp_che_n_bco   number(18,2) := 0;   -- che.ntro.bco
v_imp_che_o_bco   number(18,2) := 0;   -- che otros bcos.
v_tot_deposito    number(18,2) := 0;   -- total
-- datos a responder (solo se setea el codigo de respuesta)
-- variables
v_nro_cuenta      varchar2(17);  -- numero de cuenta
v_cod_moneda      varchar2(3);   -- moneda de la cuenta
v_est_cuenta      varchar2(1);   -- estado de la cuenta
v_cod_mod_cta     number(4);     -- modulo de la cuenta
v_cod_mad_cta     number(4);     -- modalidad de la cuenta
v_cod_ofi_cta     number(4);     -- oficina de la cuenta
v_cod_tra_padre   number(4);     -- cod. transaccion padre
v_cod_transaccion number(4);     -- cod. transaccion
v_cod_retencion   number(4);     -- codigo de retencion
v_fec_fin_retencion date;        -- fecha final de la retencion
v_nvo_estado      varchar2(1) := null; -- cambio de estado de cuenta
begin
  -- 0. inicializo la secuencia
  v_nro_secuencia := 0;
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     v_nro_cuenta   := lf_obt_cta_limpia(substr(p_parametros,66,16)); -- nro de tarjeta a pagar
     v_nro_sobre    := to_number(trim(substr(p_parametros,82,10)));   -- sobre
     begin
        select a.nro_cuenta, a.cod_moneda, a.estado, cod_modalidad,
               cod_modulo, cod_oficina
          into v_nro_cuenta, v_cod_moneda,
               v_est_cuenta, v_cod_mad_cta, v_cod_mod_cta, v_cod_ofi_cta
          from ge_cuentas a
         where a.nro_cuenta = v_nro_cuenta; -- contiene el nro de cuenta
         -- deposito
         if v_cod_mad_cta not in (31,41) then
            v_cod_respuesta := paw_bce.v_cod_cta_invalida;
         elsif v_est_cuenta not in ('A','I','N','S') then
            v_cod_respuesta := paw_bce.v_cod_cta_invalida;
         elsif pag_cta.fu_ver_tra_prohibida(v_nro_cuenta,393, 9, 91) = 'S' then
            v_cod_respuesta := paw_bce.v_cod_tra_prohibida;
         end if;
     exception
        when no_data_found then
           v_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
        when too_many_rows then
           v_cod_respuesta  := paw_bce.v_cod_cta_duplicada;
        when others then
           v_cod_respuesta  := paw_bce.v_cod_cta_invalida;
     end;
     if v_cod_respuesta = paw_bce.v_cod_aprobado then
        -- esta la cuenta en condiciones, verifico el horario del deposito
        lp_ver_horario;
        -- verifico la validez de los montos
        begin
          v_imp_efectivo  := nvl(to_number(replace(trim(substr(p_parametros,92,18)),',','.')),0);   -- efectivo
          v_imp_che_n_bco := nvl(to_number(replace(trim(substr(p_parametros,110,18)),',','.')),0);  -- che.ntro.bco
          v_imp_che_o_bco := nvl(to_number(replace(trim(substr(p_parametros,128,18)),',','.')),0);  -- che otros bcos.
          v_tot_deposito  := nvl(to_number(replace(trim(substr(p_parametros,146,18)),',','.')),0);   -- total
          if v_cod_moneda = v_cod_mon_local then
             if v_imp_efectivo <> trunc(v_imp_efectivo) or
                v_imp_che_n_bco <> trunc(v_imp_che_n_bco) or
                v_imp_che_o_bco <> trunc(v_imp_che_o_bco) then
               -- monto con decimales y en guaranies no permite
               v_cod_respuesta := paw_bce.v_cod_mto_invalido;
             elsif nvl(v_imp_efectivo,0) + nvl(v_imp_che_n_bco,0) +
                   nvl(v_imp_che_o_bco,0) <> nvl(v_tot_deposito,0) then
                   -- total depositado invalido
                   v_cod_respuesta := paw_bce.v_cod_tot_invalido;
             end if;
          end if;
        exception
          when others then
             -- monto invalido
             v_cod_respuesta := paw_bce.v_cod_mto_invalido;
        end;
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
          -- sigue sin problemas hasta aqui, ya puedo grabar
          if v_horario = 'D' then
             -- Horario normal, se actualiza las cuentas y montos del diar
             if v_cod_mad_cta = 31 then -- ahorro vista
                update ah_cta_vistas
                   set sal_total    = nvl(sal_total,0) + nvl(v_tot_deposito,0),
                       sal_retenido = nvl(sal_retenido,0) + nvl(v_tot_deposito,0),
                       fec_ult_movimiento = v_fec_actual
                 where nro_cuenta = v_nro_cuenta;
             elsif v_cod_mad_cta = 41 then -- cuenta corriente
                update cc_cta_corrientes
                   set sal_total    = nvl(sal_total,0) + nvl(v_tot_deposito,0),
                       sal_retenido = nvl(sal_retenido,0) + nvl(v_tot_deposito,0),
                       fec_ult_movimiento = v_fec_actual
                 where nro_cuenta = v_nro_cuenta;
             else
                v_cod_respuesta := paw_bce.v_cod_cta_invalida;
                return null;
             end if;

          elsif v_horario = 'T' then
             -- Tarde, ya se cerro el autoservicio del dia,
             if v_cod_mad_cta = 31 then -- ahorro vista
                update ah_cta_vistas
                   set mto_cre_a_confirmar = nvl(mto_cre_a_confirmar,0) + nvl(v_tot_deposito,0)
                 where nro_cuenta = v_nro_cuenta;
             elsif v_cod_mad_cta = 41 then -- cuenta corriente
                update cc_cta_corrientes
                   set mto_cre_a_confirmar = nvl(mto_cre_a_confirmar,0) + nvl(v_tot_deposito,0)
                 where nro_cuenta = v_nro_cuenta;
             else
                v_cod_respuesta := paw_bce.v_cod_cta_invalida;
                return null;
             end if;

          elsif v_horario = 'N' then
             -- el sistema esta cerrado, se actualiza las cuentas nocturnas
             if v_cod_mad_cta = 31 then -- ahorro vista
                update ah_cta_vistas_noc
                   set mto_cre_a_confirmar = nvl(mto_cre_a_confirmar,0) + nvl(v_tot_deposito,0)
                 where nro_cuenta = v_nro_cuenta;
             elsif v_cod_mad_cta = 41 then -- cuenta corriente
                update cc_cta_corrientes_noc
                   set mto_cre_a_confirmar = nvl(mto_cre_a_confirmar,0) + nvl(v_tot_deposito,0)
                 where nro_cuenta = v_nro_cuenta;
             else
                v_cod_respuesta := paw_bce.v_cod_cta_invalida;
                return null;
             end if;

          end if;
          if sql%notfound then
             -- no se encontro registro de actualizacion
             v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
             return null;
          end if;
          -- actualizo el control de caja
          update cj_controles
             set tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_imp_che_n_bco,0),
                 sal_actual = nvl(sal_actual,0) + nvl(v_imp_efectivo,0),
                 tot_debitos = nvl(tot_debitos,0) + nvl(v_imp_efectivo,0),
                 can_debitos = nvl(can_debitos,0) + decode(v_imp_efectivo,0,0,1),
                 tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_imp_che_o_bco,0),
                 sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_imp_che_o_bco,0),
                 estado = 1 -- abierto
           where nro_caja = to_number(v_nro_terminal)
             and cod_moneda = v_cod_moneda
             and fecha = v_fec_actual;
          if sql%notfound then
             insert into cj_controles
               (nro_caja, cod_moneda, fecha, estado,
                mto_apertura, ini_che_otr_bco, cod_usu_actual,
                tot_che_nue_bco, sal_actual, tot_debitos,
                can_debitos, tot_che_otr_bco, sal_che_otr_bco)
             select
                v_nro_terminal, v_cod_moneda, v_fec_actual, 1,
                0, 0, v_cod_usuario,
                v_imp_che_n_bco, v_imp_efectivo, v_imp_efectivo,
                decode(v_imp_efectivo,0,0,1), v_imp_che_o_bco,
                v_imp_che_o_bco from dual;
          end if;
          -- genero los movimientos respectivos
          if v_imp_efectivo > 0 then
             -- importe en efectivo
              v_cod_tra_padre   := 393;
              v_cod_transaccion := 613;
              -- v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
              -- DYDMR-773 ERROR EN TAS - SC 5610
              v_hor_actual := FUG_OBT_HOR_DISPONIBLE(v_fec_actual,
                                                     v_hor_actual,
                                                     user,
                                                     v_es_mov_noc);
              -- obtengo el codigo y fin de retencion
              pag_cta.pr_obt_retencion(v_fec_actual,
                                       v_nro_cuenta,
                                       v_cod_mod_cta,
                                       v_cod_mad_cta,
                                       v_cod_transaccion,
                                       v_cod_moneda,
                                       v_cod_retencion,
                                       v_fec_fin_retencion);
              -- genero el movimiento respectivo
              lp_ins_movimiento( v_cod_mod_cta,
                                 v_cod_mad_cta,
                                 v_cod_ofi_cta,
                                 v_nro_cuenta,
                                 v_cod_moneda,
                                 v_cod_tra_padre,
                                 v_cod_transaccion,
                                 v_nro_sobre,
                                 v_imp_efectivo,
                                 'E', -- EFECTIVO
                                 v_es_mov_noc,
                                 v_cod_retencion,
                                 v_fec_fin_retencion);
          end if;
          if v_imp_che_n_bco > 0 then
             -- importe en cheques ntro banco
              v_cod_tra_padre   := 394;
              v_cod_transaccion := 614;
              -- v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
              -- DYDMR-773 ERROR EN TAS - SC 5610
              v_hor_actual := FUG_OBT_HOR_DISPONIBLE(v_fec_actual,
                                                     v_hor_actual,
                                                     user,
                                                     v_es_mov_noc);
              -- obtengo el codigo y fin de retencion
              pag_cta.pr_obt_retencion(v_fec_actual,
                                       v_nro_cuenta,
                                       v_cod_mod_cta,
                                       v_cod_mad_cta,
                                       v_cod_transaccion,
                                       v_cod_moneda,
                                       v_cod_retencion,
                                       v_fec_fin_retencion);
              -- genero el movimiento respectivo
              lp_ins_movimiento( v_cod_mod_cta,
                                 v_cod_mad_cta,
                                 v_cod_ofi_cta,
                                 v_nro_cuenta,
                                 v_cod_moneda,
                                 v_cod_tra_padre,
                                 v_cod_transaccion,
                                 v_nro_sobre,
                                 v_imp_che_n_bco,
                                 'C', -- cheque ntro bco
                                 v_es_mov_noc,
                                 v_cod_retencion,
                                 v_fec_fin_retencion);
          end if;
          v_imp_alt_valor := fug_obt_pardinamico('MTO_CHE_RET_CERO',null,null,v_cod_moneda,null,null );
          if v_imp_che_o_bco > 0 then
             -- importe en cheques otros bancos
              v_cod_tra_padre   := 395;
              IF v_cod_moneda = v_cod_mon_local THEN             
                  if v_horario = 'D' and v_hor_actual > v_hor_cie_cheques then
                    -- se graba ya como cheques 48 hs de retencion
                    v_cod_transaccion := 632;
                    v_tip_monto       := 'S';
                  else
                    v_cod_transaccion := 615;
                    v_tip_monto       := 'T';
                  end if;
                --end if;       
              ELSE
                v_cod_transaccion := 615;
                v_tip_monto       := 'T';  
                IF v_horario = 'D' and v_hor_actual > v_hor_cie_cheques THEN
                   -- se graba ya como cheques 48 hs de retencion
                   v_cod_transaccion := 632;
                   v_tip_monto       := 'S';
                END IF;
              END IF;  
              -- v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
              -- DYDMR-773 ERROR EN TAS - SC 5610
              v_hor_actual := FUG_OBT_HOR_DISPONIBLE(v_fec_actual,
                                                     v_hor_actual,
                                                     user,
                                                     v_es_mov_noc);
              -- obtengo el codigo y fin de retencion
              pag_cta.pr_obt_retencion(v_fec_actual,
                                       v_nro_cuenta,
                                       v_cod_mod_cta,
                                       v_cod_mad_cta,
                                       v_cod_transaccion,
                                       v_cod_moneda,
                                       v_cod_retencion,
                                       v_fec_fin_retencion);
              -- genero el movimiento respectivo
              lp_ins_movimiento( v_cod_mod_cta,
                                 v_cod_mad_cta,
                                 v_cod_ofi_cta,
                                 v_nro_cuenta,
                                 v_cod_moneda,
                                 v_cod_tra_padre,
                                 v_cod_transaccion,
                                 v_nro_sobre,
                                 v_imp_che_o_bco,
                                 v_tip_monto, -- cheque otros bcos
                                 v_es_mov_noc,
                                 v_cod_retencion,
                                 v_fec_fin_retencion);
          end if;
          -- cambio estado de la cuenta
          if v_est_cuenta in ('A','I') then
               v_nvo_estado := 'N';
               pag_cta.pr_obt_cuenta(v_nro_cuenta);
               -- restauro el estado de la cuenta --
               v_nro_secuencia := v_nro_secuencia + 1;
               pag_cta.pr_set_variables(v_cod_usuario,
                                        v_fec_valor,
                                        v_cod_tra_padre,
                                        'N', -- estado del movimiento
                                        'N', -- reversado s/n
                                        v_nro_secuencia,
                                        v_nvo_estado,
                                        v_cod_ofi_origen,
                                        9,
                                        91);
                /* Actualiza el estado y genera el movimiento */
                 pag_cta.pr_act_estado(v_nro_cuenta,
                                       v_nvo_estado,
                                       v_fec_actual,
                                       v_hor_actual,
                                       v_nro_sobre,
                                       'S');
                 if pag_cta.g_cod_error <> 0 then
                    raise_application_error(-20008,'Error en act.estado '||pag_cta.G_MSJ_ERROR);
                 end if;
           end if;
        end if;
     end if;
  end if;
  -- registro del movimiento
  lp_reg_operacion(v_nro_cuenta /*p_nro_cuenta*/,
                   v_cod_moneda /*p_cod_moneda */,
                   v_tot_deposito /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Efectivo' /*p_etiqueta*/,
                   v_imp_efectivo /**/,
                   'Cheques',
                   v_imp_che_n_bco + v_imp_che_o_bco
                 );
  -- no se responde nada, solo se debe setear el v_cod_respuesta
  return null;
end;
-- fin de 015-confirmacion de deposito en cuenta

-- BSEVOCORE-583 Corte / Vaciamiento de Buzon del autoservicio
function fu_pro_operacion_016(p_parametros in varchar2)
  return varchar2 is
v_can_sobres number(4); -- cantidad de sobres
begin
   v_can_sobres := 0;
   -- 1. Cuento los sobres ingresados desde el ultimo cierre
   select count(*)
     into v_can_sobres
     from ge_movimientos
    where cod_usuario = v_cod_usuario
      and estado = 'N'
      and reversado = 'N'
      and nro_caja = v_nro_terminal
      and nro_documento is not null
      and nro_secuencia = 1
      and cod_mod_padre = 9
      and cod_mad_padre = 91
      and cod_tra_padre in (392,393,394,495,395,450,250)
      and fec_insercion > v_ult_corte;
   -- 2. actualizo la fecha de corte
   pr_act_corte;
   commit;
   -- retorno la cantidad de sobres
   return lf_for_number(v_can_sobres,4);
end;
-- Fin del cierre

-- Cierre del autoservicio
function fu_pro_operacion_017(p_parametros in varchar2)
  return varchar2 is
v_can_sobres number(4); -- cantidad de sobres
begin
   -- 1. Cuento los sobres ingresados desde el ultimo cierre
   select count(*)
     into v_can_sobres
     from ge_movimientos
    where cod_usuario = v_cod_usuario
      and estado = 'N'
      and reversado = 'N'
      and nro_caja = v_nro_terminal
      and nro_documento is not null
      and nro_secuencia = 1
      and cod_mod_padre = 9
      and cod_mad_padre = 91
      and cod_tra_padre in (392,393,394,495,395,450,250)
      and fec_insercion > v_ult_corte; -- BSEVOCORE-583
   -- 2. actualizo la fecha de cierre
   v_ult_cierre := sysdate;
   update cj_cajas
      set fec_hor_cierre = v_ult_cierre
    where nro_caja = to_number(paw_bce.v_nro_terminal);
   --BSEVOCORE-583 actualiza cortes
   pr_act_corte;
   commit;
   -- retorno la cantidad de sobres
   return lf_for_number(v_can_sobres,4);
end;
-- Fin del cierre

-- Devuelve el saldo detallado de las cuentas
function fu_pro_operacion_020(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_ver_todas      varchar2(3)      := substr(p_parametros,66,1);   -- ver todas las cuentas s/n
v_nro_cta_especifica varchar2(16) := trim(substr(p_parametros,67,16)); -- cuenta especifica a consultar
-- datos a responder
v_can_detalles    number(3);     -- cantidad de cuentas
--
v_detalles        clob := null;   -- datos de las cuentas
v_det_cuotas      varchar2(3000); -- detalle de las cuotas
-- variables
v_monto1          number(18,2) := 0;   -- monto 1
v_monto2          number(18,2) := 0;   -- monto 2
v_monto3          number(18,2) := 0;   -- monto 3
v_monto4          number(18,2) := 0;   -- monto 4
v_monto5          number(18,2) := 0;   -- monto 5
v_monto6          number(18,2) := 0;   -- monto 6
v_val_tasa        number(10,4) := null;
v_fec_inicio      date;
v_fec_vencimiento date;
v_dia_mora        number;
v_che_devuelto    varchar2(01);
v_can_cuotas      number(5);
-- OMM 10/11/2011
v_avisos          varchar2(1) := 'N' ;
--
v_cta_formateada varchar2(17);
v_fec_prox_vcto   date := NULL;
v_tip_cierre       TA_CTA_TARJETAS.COD_TIP_CIERRE%TYPE;

-- cursor de cuentas del cliente
cursor cuentas is
  select a.nro_cuenta, a.cod_modalidad cod_modalidad,
         fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina,a.nro_cuenta, a.cod_moneda) cta_formateada,
         fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta,
         decode(b.relacion, 'C', 'Codeudor', 'G', 'Codeudor', fug_obt_des_modal(a.cod_modulo,a.cod_modalidad)) des_tip_cuenta,
         a.cod_moneda cod_moneda, a.denominacion nom_cuenta,
         a.cod_modulo
    from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
   where a.nro_cuenta = b.nro_cuenta
     and ((b.relacion in ('O','P','Y') and b.cod_modulo != 6) or
          (b.relacion in ('O','C','G','P') and b.cod_modulo = 6))
     and b.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
     and a.cod_modulo = c.cod_modulo
     and a.cod_modalidad = c.cod_modalidad
     and a.estado = c.estado
     and b.cod_modulo != 7
     and b.cod_modalidad <> 36
     and c.activo = 'S'  -- solo cuentas activas
     and a.estado <> 'X' -- pendiente de verificacion
     and (v_ver_todas = 'S' or b.nro_cuenta = v_nro_cta_especifica) -- solo ve la cuenta recibida o todas
   order by decode(b.cod_modalidad,31,1,
                   decode(b.cod_modulo,5,2,
                          decode(b.cod_modalidad,33,4,34,4,36,4,
                                 decode(b.cod_modulo,4,3,7))));
cursor cuotas(p_nro_cuenta in varchar2) is
  select  nro_cuota,
          nvl(sal_capital,0) + nvl(sal_interes,0) + nvl(sal_int_documentado,0) mto_cuota,
          fec_vencimiento, fec_ult_pago,
          /*decode(sign(v_fec_actual - fec_vencimiento),1,
                 (v_fec_actual-fec_vencimiento), 0 ) se anulo a pedido de BBVA */ 0 dia_mora
    from pr_cuotas a
   where nro_cuenta = p_nro_cuenta
     and nro_cuota > 0
     and estado <> 'N'
     and fec_vencimiento <= (select nvl(min(fec_vencimiento),v_fec_actual)
                              from pr_cuotas b
                             where b.nro_cuenta = p_nro_cuenta
                               and nro_cuota > 0
                               and estado <> 'N'
                               and fec_vencimiento >= v_fec_actual)
   order by nro_cuota;
begin
  -- 0. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 1. Armo el nro de cuenta
  v_nro_cta_especifica := lf_obt_cta_limpia(v_nro_cta_especifica);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     v_can_detalles := 0;
     for ct in cuentas loop

       --- Debe controlar para que no muestre cuentas juridicas entre las cuentas del cliente
       If fu_es_juridica(ct.nro_cuenta) = 'N' then
         v_can_detalles := v_can_detalles + 1;
         if ct.cod_modulo = 5 then
           v_cta_formateada := lf_obt_nro_tarjeta(ct.nro_cuenta);
         else
           v_cta_formateada := ct.cta_formateada;
         end if;
         v_detalles :=  v_detalles ||
                        lf_for_char(v_cta_formateada,17)||
                        lf_for_char(ct.cod_tip_cuenta,2)||
                        lf_for_char(ct.des_tip_cuenta,35)||
                        lf_for_char(ct.nom_cuenta,50)||
                        lf_for_char(rpad(ct.cod_moneda,3,'.'),3);
         v_monto1          := 0;   -- monto 1
         v_monto2          := 0;   -- monto 2
         v_monto3          := 0;   -- monto 3
         v_monto4          := 0;   -- monto 4
         v_monto5          := 0;   -- monto 5
         v_monto6          := 0;   -- monto 6
         v_val_tasa        := null;
         v_fec_inicio      := null;
         v_fec_vencimiento := null;
         v_dia_mora        := 0;
         v_che_devuelto    := 'N';
         v_can_cuotas      := 0;
         -- busco los demas datos de las cuentas
         begin
            if ct.cod_modulo = 6 then  -- prestamos
               select monto, nvl(sal_capital,0) + nvl(sal_int_adelantado,0),
                      nvl(sal_interes,0), 0,
                      val_tasa, fec_inicio, fec_vencimiento, /* dia mora 0 a pedido de bbva */ 0 dia_atraso,
                      'N'
                 into v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa,
                      v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto
                 from pr_cta_prestamos
                where nro_cuenta = ct.nro_cuenta;
               v_can_cuotas := 0;
               v_det_cuotas := null;
               for cu in cuotas(ct.nro_cuenta) loop
                   v_can_cuotas := v_can_cuotas + 1;
                   v_det_cuotas := v_det_cuotas ||
                                   lf_for_number(cu.nro_cuota,5)||
                                   lf_for_money(cu.mto_cuota,16)||
                                   lf_for_date(cu.fec_vencimiento)||
                                   lf_for_date(cu.fec_ult_pago)||
                                   lf_for_number(cu.dia_mora,5);
               end loop;
            elsif ct.cod_modulo = 5 then  -- tarjetas
               select nvl(lin_credito,0) - (nvl(sal_facturar,0)+
                                      nvl(sal_facturado,0)+
                                      nvl(sal_financiado,0)+
                       nvl(sal_cuo_pendientes,0)),
                      (nvl(sal_facturar,0)+
                         nvl(sal_facturado,0)+
                         nvl(sal_financiado,0)+
                         nvl(sal_cuo_pendientes,0)),
            -- OMM 12/11/2010 Analisis Funcional y AP Nro.: 1037.1
                      --nvl(sal_pag_minimo,0),
            decode(nvl(sal_pag_minimo,0), 0, nvl(mto_mora, 0), nvl(sal_pag_minimo,0)),
                      nvl(lin_credito,0),
                      tas_financiacion,
                      fec_ult_cierre,
                      fec_vct_ult_cierre,
                      dia_mora,
                      'N',
                      lin_cuotas, cod_tip_cierre
                 into v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa,
                      v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto,
                      v_monto5, v_tip_cierre
                 from ta_cta_tarjetas
                where nro_cuenta = ct.nro_cuenta;
               if v_ver_todas='A' then
                  -- datos actuales de la procesadora
                  pag_ban.pr_con_saldos(replace(v_cta_formateada,' ',''));
                  if pag_ban.fu_obt_cod_error() != '00' then
                     -- tiene error
                     v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
                  else
                     -- reemplzo los daots de hoy
                     v_monto1 := pag_ban.fu_Dis_com_normal()/* + pag_ban.fu_Dis_com_cuotas()*/;
                     v_monto2 := pag_ban.fu_Deu_total();
                     v_monto3 := pag_ban.fu_Pago_min_pendiente();
                     v_monto4 := pag_ban.fu_Lin_credito();
                     --v_monto5 := linea en cuotas (no se tiene);
                     v_fec_prox_vcto :=  pag_ban.fu_Fec_pro_cierre();
                     v_fec_vencimiento := pag_ban.fu_Fec_ven_pag_minimo();
                     --v_val_tasa := no se tiene;
                     -- v_fec_inicio := no  se tiene
                     -- v_dia_mora := no se tiene
                     -- v_che_devuelto := no se tiene
                     -- v_tip_cierre, := no se tiene
                  end if;
               else
                 -- veo los datos de ayer
                 -- Busco la fecha del sgte vcto despues del ultimo cierre(v_fec_inicio = fec_ult_cierre)
                 -- Primero busco si existe un vcto cargado para esa modalidad
                  select min(fec_cierre)
                  into v_fec_prox_vcto
                  from ta_cal_cierres v
                where cod_ent_procesadora =  fug_obt_pardinamico('COD_PRO_BANCARD')
                  and v.cod_modulo = ct.cod_modulo
                  and v.cod_modalidad = ct.cod_modalidad
                  and v.cod_tip_cierre = v_tip_cierre
                  and fec_cierre > v_fec_inicio;

                  -- si ya pago se busca el siguiente cierre, o ya hay nuevo cierre
                  if v_monto3 = 0 then
                 select min(fec_cierre), min(fec_vencimiento)
                   into v_fec_prox_vcto, v_fec_vencimiento
                   from ta_cal_cierres v
                  where cod_ent_procesadora =  fug_obt_pardinamico('COD_PRO_BANCARD')
                    and v.cod_modulo = ct.cod_modulo
                    and v.cod_modalidad = ct.cod_modalidad
                    and v.cod_tip_cierre = v_tip_cierre
                    and fec_cierre > v_fec_inicio;
                  end if;

                  -- Si no existe para esa modalidad busco el vcto general
                 if v_fec_prox_vcto is null then
                    select min(fec_cierre), min(fec_vencimiento)
                      into v_fec_prox_vcto, v_fec_vencimiento
                      from ta_cal_cierres v
                     where cod_ent_procesadora =  fug_obt_pardinamico('COD_PRO_BANCARD')
                       and v.cod_modulo = ct.cod_modulo
                       and v.cod_modalidad is null
--                       and v.tip_cierre = v_tip_cierre
                       and fec_cierre > v_fec_inicio;
                 end if;
                 -- Si no existe (puede ser que no se cargo) despliego el ultimo cierre
                 if v_fec_prox_vcto is null then
                    v_fec_prox_vcto := v_fec_inicio;
                 end if;

                 v_fec_inicio := v_fec_prox_vcto;
               end if;

            elsif ct.cod_modalidad = 31 then -- ahorro vista
               pag_cta.PR_OBT_CUENTA(ct.nro_cuenta);
               --
               v_monto1 := pag_cta.g_ctas.sal_actual;
               v_monto2 := pag_cta.g_ctas.sal_disponible;
               v_monto3 := pag_cta.g_ctas.sal_retenido;  --pag_cta.g_ctas.mto_cre_a_confirmar;
               v_monto4 := 0;
               v_val_tasa := pag_cta.g_ctas.val_tasa;
               v_fec_inicio := pag_cta.g_ctas.fec_apertura;
               v_fec_vencimiento := pag_cta.g_ctas.fec_vencimiento;
               v_dia_mora := 0;
               v_che_devuelto := 'N';
/*               select nvl(sal_total,0),
                      nvl(sal_total,0) - nvl(sal_retenido,0)-
                      nvl(sal_bloqueado,0),
                      nvl(mto_cre_a_confirmar,0),
                      nvl(sal_retenido,0),
                      fug_obt_val_tasa(cod_modulo,
                              cod_modalidad,
                              cod_oficina,
                              nro_cuenta,
                              cod_moneda,
                              sal_total,
                              tas_personalizada,
                              cod_tasa,
                              null,
                              v_fec_actual) val_tasa,
                      fec_apertura,
                      null,
                      0,
                      'N'
                 into v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa,
                      v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto
                 from ah_cta_vistas
                where nro_cuenta = ct.nro_cuenta;*/
            elsif ct.cod_modalidad in (33,34,35,36) then -- cda
               select capital,
                      nvl(int_pendiente,0) int_pendiente,
                      nvl(sal_retenido,0),
                      0,
                      fug_obt_val_tasa(cod_modulo,
                              cod_modalidad,
                              cod_oficina,
                              nro_cuenta,
                              cod_moneda,
                              capital,
                              tas_personalizada,
                              cod_tasa,
                              null,
                              v_fec_actual) val_tasa,
                      fec_apertura,
                      fec_vencimiento,
                      0,
                      'N'
                 into v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa,
                      v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto
                 from ah_cta_certificados,(select nro_cuenta cuenta,
                                                  sum(mto_interes) int_pendiente
                                             from ah_cupones
                                            where estado in ('V','E')
                                            group by nro_cuenta) b
                where nro_cuenta = ct.nro_cuenta
                  and b.cuenta(+) = nro_cuenta;

            elsif ct.cod_modalidad = 41 then -- cuenta corriente
               begin
                 select can_dias
                   into  v_dia_mora
                   from cc_sobregiros_res
                  where nro_cuenta = ct.nro_cuenta;
               exception
                  when others then
                     v_dia_mora := 0;
               end;
               pag_cta.PR_OBT_CUENTA(ct.nro_cuenta);
               --
               v_monto1 := pag_cta.g_ctas.sal_actual;
               v_monto2 := pag_cta.g_ctas.sal_disponible;
               v_monto3 := pag_cta.g_ctas.sal_retenido; --pag_cta.g_ctas.mto_cre_a_confirmar;
               v_monto4 := pag_cta.FU_OBT_LIN_SOBREGIRO(ct.nro_cuenta,v_fec_actual);
               v_val_tasa := pag_cta.g_ctas.val_tasa;
               v_fec_inicio := pag_cta.g_ctas.fec_apertura;
               v_fec_vencimiento := pag_cta.g_ctas.fec_vencimiento;
               --v_dia_mora := 0;
               v_che_devuelto := 'N';
            end if;
         exception
            when others then
              v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
         end;
         if v_cod_respuesta = paw_bce.v_cod_aprobado then
            v_che_devuelto := lf_obt_che_devuelto(ct.nro_cuenta);
            -- esta bien el dato se carga el detalle
            v_detalles := v_detalles ||
                          lf_for_money(v_monto1,16)||
                          lf_for_money(v_monto2,16)||
                          lf_for_money(v_monto3,16)||
                          lf_for_money(v_monto4,16)||
--                          lf_for_money(v_monto5,16)||
                          lf_for_money(v_val_tasa,8)||
                          lf_for_date(v_fec_inicio)||
                          lf_for_date(v_fec_vencimiento)||
                          lf_for_number(v_dia_mora,5)||
                          lf_for_char(v_che_devuelto,1)||
                          lf_for_number(v_can_cuotas,3)||
                          v_det_cuotas;
         end if;
       end if;
       if v_can_detalles >= 999 then
          exit;
       end if;
     end loop;
     if v_can_detalles = 0 then
        -- no tiene detalles
         v_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
     end if;
  end if;
  -- OMM 10/11/2011  Identificación de nuevo mensaje al cliente
  Begin
     Select distinct('S')
       into v_avisos
       from cr_per_notas
      where tipo in ('C', 'M')
        and estado = 'P'
        and cod_persona = nvl(v_cod_per_empresa, v_cod_persona);
  exception
     when others then
          v_avisos := 'N';
  end;

  -- registro del movimiento
  lp_reg_operacion(v_nro_cta_especifica /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Ver Todas' /*p_etiqueta*/,
                   v_ver_todas /*p_dato*/
                 );
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return lf_for_number(v_can_detalles,3)||
            v_detalles||v_avisos;

  else
     return null;  -- nada
  end if;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 020 - Saldo detallado de cuentas

-- 021 Movimientos por cuenta
function fu_pro_operacion_021(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_nro_pagina     number(3)   := substr(p_parametros,66,2);   -- nro de pagina
v_can_dias       number(3)   := 60;   -- dias a mostrar
v_ver_todas      varchar2(3) := substr(p_parametros,68,1);   -- ver todas las cuentas s/n
v_nro_cta_especifica varchar2(16) := trim(substr(p_parametros,69,16)); -- cuenta especifica a consultar
-- datos a responder
v_can_detalles    number(3);     -- cantidad de cuentas
--
v_detalles        clob := null;   -- datos de las cuentas
v_det_movimientos clob;           -- detalle de los movimientos
-- variables
v_monto1          number(18,2) := 0;   -- monto 1
v_monto2          number(18,2) := 0;   -- monto 2
v_monto3          number(18,2) := 0;   -- monto 3
v_che_devuelto    varchar2(01);
v_can_movimientos number(8);
v_can_enviados    number(8);
v_saldo           number(18,2) := 0;
v_fec_inicio      date := to_date('01'||to_char(v_fec_actual-89,'mmyyyy'),'ddmmyyyy');
v_can_limite      number(8) := 50;
v_fec_insercion   date;
v_det_temporal    long; -- esto es para ir cargando los datos en forma temporal
v_nro_secuencia   number(6);
v_pri_dia_hab     date := pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1);

v_reg_inicial     number(10);
v_reg_final       number(10);
v_fin             varchar2(1);
v_can_pagina      number(5) := 60;  -- movimientos por pagina
v_des_tra_padre   gv_movimientos.DES_TRA_PADRE%TYPE; -- para pago de prestamos por homebanking
v_nro_Documento   gv_movimientos.NRO_DOCUMENTO%type;


-- cursor de cuentas pasivas del cliente
cursor cuentas is
  select a.nro_cuenta, a.cod_modalidad cod_modalidad,
         fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina,a.nro_cuenta, a.cod_moneda) cta_formateada,
         fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta,
         fug_obt_des_modal(a.cod_modulo,a.cod_modalidad) des_tip_cuenta,
         a.cod_moneda cod_moneda, a.denominacion nom_cuenta,
         a.cod_modulo
    from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
   where a.nro_cuenta = b.nro_cuenta
     and b.relacion in ('O', 'P','Y')
     and b.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
     and a.cod_modulo = c.cod_modulo
     and a.cod_modalidad = c.cod_modalidad
     and a.estado = c.estado
     and c.activo = 'S'  -- solo cuentas activas
     and a.estado <> 'X' -- pendiente de verificacion
     and b.cod_modalidad in (31,41)
     and (v_ver_todas = 'S' or b.nro_cuenta = v_nro_cta_especifica); -- solo ve la cuenta recibida o todas
-- movimientos por cuenta
cursor movimientos(p_nro_cuenta in varchar2) is
  select fecha, fec_valor, decode(a.COD_MAD_PADRE,455, substr(nro_documento,-7), nro_documento) nro_documento, 
         des_tra_padre, decode(fu_caj_homebanking(v_nro_terminal),'S', replace(a.hora, ':', ''), abr_tra_padre) abr_tra_padre,
         fug_obt_tra_tipo(b.cod_transaccion,b.tipo,b.afecta) cod_tip_movimiento, monto, hora, nro_secuencia,
          a.fec_insercion, a.TIPO, a.NRO_CAJA,a.COD_TRANSACCION,COD_TRA_PADRE,a.cod_usuario
    from ge_transacciones b, gv_movimientos a
   where nro_cuenta = p_nro_cuenta
     and estado = 'N'
     and (a.reversado = 'N' 
      or (a.reversado = 'S' and a.fec_valor < trunc(sysdate))
      or (a.reversado = 'S' and a.COD_TRA_PADRE=303)-- BBVASOP-888/AP 3056
      )
     and monto <> 0
     and cod_tip_movimiento in ('D','C')
     --and fecha >= v_fec_actual - v_can_dias
     and fecha >= v_fec_inicio
     and a.cod_modulo = b.cod_modulo
     and a.cod_modalidad = b.cod_modalidad
     and a.cod_transaccion = b.cod_transaccion
     and b.ve_cliente = 'S'
     and not exists (select 0 from ah_retenciones x
                      where x.nro_cuenta = a.nro_cuenta
                        and x.nro_documento = a.nro_documento
                        and x.cod_retencion = a.cod_retencion
                        and x.fec_final = a.fec_fin_retencion
                        and x.liberado = 'N')
   order by a.fec_insercion desc, nro_secuencia desc;
/*cursor movimientos2(p_nro_cuenta in varchar2, p_fec_insercion date, p_nro_secuencia in number) is
  select fecha, fec_valor, nro_documento, des_tra_padre, decode(v_nro_terminal,'999', replace(a.hora, ':', ''), abr_tra_padre) abr_tra_padre,
         cod_tip_movimiento, monto
    from ge_transacciones b, gv_movimientos a
   where nro_cuenta = p_nro_cuenta
     and estado = 'N'
     and reversado = 'N'
     and monto <> 0
     and cod_tip_movimiento in ('D','C')
     --and fecha >= v_fec_actual - v_can_dias
     and fecha >= v_fec_inicio
     and a.cod_modulo = b.cod_modulo
     and a.cod_modalidad = b.cod_modalidad
     and a.cod_transaccion = b.cod_transaccion
     and b.ve_cliente = 'S'
     and not exists (select 0 from ah_retenciones x
                      where x.nro_cuenta = a.nro_cuenta
                        and x.nro_documento = a.nro_documento
                        and x.cod_retencion = a.cod_retencion
                        and x.fec_final = a.fec_fin_retencion
                        and x.liberado = 'N')
     and ((a.fec_insercion > p_fec_insercion) or
          (a.fec_insercion = p_fec_insercion and a.nro_secuencia >= p_nro_secuencia))
   order by a.fec_insercion, nro_secuencia;*/

begin
  -- 0. Inicializo el campo can_dias
  if nvl(v_can_dias,0) <= 0 then
     v_can_dias := 7;
  end if;
  if fu_caj_homebanking(v_nro_terminal) = 'S' /*v_nro_terminal = '999'*/ then
     v_can_limite :=  640;  -- temporalmente, debe ser 999 RAMG
  else
     v_nro_pagina := 1;
  end if;
  if v_nro_pagina is null then
     v_nro_pagina := 1;
  end if;
  --
  v_reg_inicial := (v_nro_pagina * v_can_pagina) - (v_can_pagina - 1);
  v_reg_final   := (v_nro_pagina * v_can_pagina);
  --Verifico si es el primer día habil para asi tomar datos del mes anterior
/*  if v_pri_dia_hab = v_fec_actual then
     --Mes anterior
     v_fec_inicio := add_months(v_fec_inicio,-1);
  end if;*/
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 1.1. Armo el nro de cuenta
  v_nro_cta_especifica := lf_obt_cta_limpia(v_nro_cta_especifica);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     v_can_detalles := 0;
     for ct in cuentas loop
       --- Debe controlar para que no muestre cuentas juridicas entre las cuentas del cliente
       If fu_es_juridica(ct.nro_cuenta) = 'N' then
         v_can_detalles := v_can_detalles + 1;
         v_detalles :=  v_detalles ||
                        lf_for_char(ct.cta_formateada,17)||
                        lf_for_char(ct.cod_tip_cuenta,2)||
                        lf_for_char(ct.des_tip_cuenta,35)||
                        lf_for_char(ct.nom_cuenta,50)||
                        lf_for_char(rpad(ct.cod_moneda,3,'.'),3);
         v_monto2          := 0;   -- monto 2
         v_monto3          := 0;   -- monto 3
         v_che_devuelto    := 'N';
         v_can_movimientos := 0;
         -- busco los demas datos de las cuentas
         begin
            pag_cta.PR_OBT_CUENTA(ct.nro_cuenta);
            v_monto2 := pag_cta.g_ctas.sal_disponible;
            v_monto3 := pag_cta.g_ctas.sal_retenido;
         exception
            when others then
              v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
         end;
         v_det_movimientos := null;
         --V_monto1 = al saldo disponible de la cuenta pero sin considerar el Bloqueado
         v_monto1          := pag_cta.g_ctas.sal_disponible + pag_cta.g_ctas.sal_bloqueado;
         --Saldo disponibles + el Saldo bloqueado que resto en el package
         v_saldo           := v_monto1;
         v_can_movimientos := 0;
         v_det_temporal    :=  null;
         v_can_enviados    := 0;
         v_fin := 'S';
         lp_ver_horario;
         -- primer ciclo solo para obtener el monto 1
         for mv in movimientos(ct.nro_cuenta) loop
               if v_horario = 'N' then
                  lp_can_reg_historicos(ct.nro_cuenta,v_fec_actual,v_horario);   
               end if;
               -- OMM 13/10/2010 se agrego para que no tome en cuenta los movimientos diarios si el horario es N (nocturno)
               if v_horario in ('D', 'T') or (v_horario = 'N' and mv.tipo in ('H', 'N')) then
                   v_can_movimientos := v_can_movimientos + 1;
                   v_fec_insercion := mv.fec_insercion;
                   v_nro_secuencia := mv.nro_secuencia;
                   if v_can_movimientos between v_reg_inicial and v_reg_final then
                       -- es un registro que debo mostrar
                       v_can_enviados := v_can_enviados + 1;
                       -- 2012/07/03: Para pago de prestamos
                       v_des_tra_padre := trim(mv.des_tra_padre);                       
                       if v_des_tra_padre = 'COBRO DE PRESTAMOS POR CAJA' and mv.nro_caja is null then
                          v_des_tra_padre := 'COBRO DE PRESTAMOS POR HOMEBANKING';
                       end if;
                       v_nro_Documento:=mv.nro_documento;
                       if mv.cod_tra_padre=303 then
                          
                          if mv.cod_transaccion = 196 then
                            v_des_tra_padre:='CARGO POR TRANS. OTROS BANCOS';
                          end if;
                          if mv.cod_transaccion = 517 then
                            v_des_tra_padre:='IVA S/COMISIONES TRANS. A OTROS BANCOS';
                          end if;
                       
                       end if;
                       
                       -- 
                       -- JIRA 1584: se agrega número de secuencia solo para homebanking
                       if fu_caj_homebanking(v_nro_terminal) = 'S' /*paw_bce.v_nro_terminal = '999'*/ then
                         v_det_temporal :=
                                 lf_for_date(mv.fecha)||
                                 lf_for_date(mv.fecha)||
                                 lf_for_number(v_nro_Documento,7)||
                                 lf_for_char(v_des_tra_padre,35)||
                                 lf_for_char(mv.abr_tra_padre,10)||
                                 lf_for_char(mv.cod_tip_movimiento,1)||
                                 lf_for_money(mv.monto,16)||
                                 lf_for_money(v_saldo,16) ||
                                 lf_for_char(mv.nro_secuencia, 4)||
                                 v_det_temporal;
                       else
                         -- reemplaza los caracteres con acento para el TAS --DYDMR-4886
                         lp_val_tas_texto(v_des_tra_padre);
                         
                         v_det_temporal :=
                                 lf_for_date(mv.fecha)||
                                 lf_for_date(mv.fecha)||
                                 lf_for_number(mv.nro_documento,7)||
                                 lf_for_char(v_des_tra_padre,35)||
                                 lf_for_char(mv.abr_tra_padre,10)||
                                 lf_for_char(mv.cod_tip_movimiento,1)||
                                 lf_for_money(mv.monto,16)||
                                 lf_for_money(v_saldo,16) ||
                                 v_det_temporal;                         
                       end if;
                       -- fin 1584
                       if (v_can_movimientos / 95) = trunc(v_can_movimientos / 95) then
                           v_det_movimientos := v_det_temporal || v_det_movimientos;
                           v_det_temporal := null;
                       end if;
                      --
                   end if;
                   if mv.cod_tip_movimiento = 'C' then
                      v_saldo := nvl(v_saldo,0) - nvl(mv.monto,0);
                   else
                      v_saldo := nvl(v_saldo,0) + nvl(mv.monto,0);
                   end if;
                   if v_can_movimientos >= v_reg_final then
                      v_fin := 'N';
                      exit;
                   end if;
             end if ;
         end loop;
         --
         v_monto1 := v_saldo;
         --
         if v_det_temporal is not null then
            v_det_movimientos := v_det_temporal || v_det_movimientos;
            v_det_temporal := null;
         end if;
         if v_cod_respuesta = paw_bce.v_cod_aprobado then
            v_che_devuelto := lf_obt_che_devuelto(ct.nro_cuenta);
            -- esta bien el dato se carga el detalle
            v_detalles := v_detalles ||
                          lf_for_money(v_monto1,16)||
                          lf_for_money(v_monto2,16)||
                          lf_for_money(v_monto3,16)||
                          lf_for_char(v_che_devuelto,1);
                       if fu_caj_homebanking(v_nro_terminal) = 'S' /*v_nro_terminal = '999'*/ then
                          v_detalles := v_detalles||
                          lf_for_number(v_can_enviados,5)||
                          v_fin||
                          v_det_movimientos;
                       else
                          v_detalles := v_detalles||
                          lf_for_number(v_can_enviados,3)||
                          v_det_movimientos;
                       end if;
         end if;
       end if;
     end loop;
     if v_can_detalles = 0 then
        -- no tiene detalles
         v_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
     end if;
  end if;
  -- registro del movimiento
  lp_reg_operacion(v_nro_cta_especifica /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Ver Todas' /*p_etiqueta*/,
                   v_ver_todas /*p_dato*/
                 );
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return lf_for_number(v_can_detalles,3)||
            v_detalles;
  else
     return null;  -- nada
  end if;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 021 - Movimientos por cuenta

-- 022- Reimpresion de comprobantes
function fu_pro_operacion_022(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_nro_cuenta      varchar2(16) := lf_obt_cta_limpia(trim(substr(p_parametros,66,16)));
v_fecha           date         := to_date(substr(p_parametros,82,8),'ddmmyyyy');
v_nro_documento   number(10)   := nvl(to_number(replace(trim(substr(p_parametros,90,7)),',','.')),0);
v_monto           number(18,2) := nvl(to_number(replace(trim(substr(p_parametros,97,16)),',','.')),0);   -- monto a transferir
v_tip_movimiento  varchar2(1)  := substr(p_parametros,113,1); -- si es debito o credito
v_factura         varchar2(1)  := trim(substr(p_parametros,114,1)); -- si es factura o no
v_nro_secuencia   number(3)    := trim(substr(p_parametros,115,4));
---
v_detalles        clob := null;   -- datos de las cuentas
  -- si la cuenta no posee al ente, se puede consultar el pago realizado a otra cuenta
  function lf_val_operacion(p_cod_persona in ge_clientes.cod_persona%type,
                            p_fecha       in varchar2,
                            p_monto       in ge_movimientos.monto%type,
                            p_referencia  in ge_movimientos.nro_documento%type,
                            p_nro_cuenta  in ge_movimientos.nro_cuenta%type) 
    return varchar2 is
  v_cod_ente ge_entes.cod_ente%type;
  v_sino varchar2(1) := 'N';
  begin
    begin
      select ge.cod_ente
        into v_cod_ente
        from ge_entes ge
       where ge.cod_persona = p_cod_persona
         and ge.tipo = 'PR';
             
      select 'S'
        into v_sino
        from ge_pag_proveedores gp
       where gp.cod_ente = v_cod_ente
         and gp.nro_cta_credito = p_nro_cuenta 
         and gp.estado = 'N'
         and gp.monto = p_monto
         and gp.referencia = p_referencia
         and gp.fec_pago = p_fecha;
    exception
      when no_data_found then
        v_sino := 'N';
      when too_many_rows then
        v_sino := 'S'; -- puede haber varios pagos con el mismo monto
      when others then 
        v_sino := 'N';
    end; 
    return v_sino; 
  end;

begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  
  -- 2. valido que el movimiento sea de la persona
  if v_cod_respuesta = paw_bce.v_cod_aprobado then    
    if lf_val_cta_origen(v_nro_cuenta, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' then
      if lf_val_operacion(nvl(v_cod_per_empresa, v_cod_persona),to_char(v_fecha), v_monto, v_nro_documento, v_nro_cuenta) = 'N' then 
        v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
      end if;
    end if;   
  end if;
    
  -- 3. ejecuto la funcion para generar el comprobante
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     v_detalles := fuw_imp_comprobante(v_nro_cuenta,v_fecha, v_nro_documento, v_monto, v_tip_movimiento, v_factura, v_nro_secuencia);
  end if;
  -- registro del movimiento
  lp_reg_operacion(v_nro_cuenta /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   v_monto /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Nro.Documento' /*p_etiqueta*/,
                   v_nro_documento /*p_dato*/,
                   'Fecha',
                   to_char(v_fecha,'dd/mm/yyyy')
                 );
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return v_detalles;
  else
     return null;  -- nada
  end if;
end;
-- fin de 022-reimpresion de comprobantes

-- 023- Consulta y confirmacion de autorizaciones pendientes
function fu_pro_operacion_023(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_modo            varchar2(3) := substr(p_parametros,66,1);   -- modo S/V/C
v_nro_documento   number(15);
v_comentario      varchar(200);
v_tip_operacion   varchar(3);
v_nro_cuenta      varchar2(20);
v_nro_cta_contra  varchar2(20);
v_descripcion     varchar2(35);
--- datos internos
---
v_cta_formateada varchar2(20);
cursor ope_pend is
       select a.nro_documento, to_char(a.fec_hora,'DD/MM/YYYY HH24:MI:SS') fec_hora, b.descripcion,
              fug_cta_formateada(c.cod_modulo, c.cod_modalidad, c.cod_oficina,c.nro_cuenta, c.cod_moneda) cta_formateada,
              a.nro_cuenta, a.cod_moneda, a.monto, c.cod_modulo, a.referencia
         from ge_cuentas c, bw_tip_mensajes b, bw_mov_pendientes a
        where a.estado = 'P'
          and a.cod_per_principal = v_cod_per_empresa
          and c.nro_cuenta = a.nro_cuenta
          and b.cod_tip_mensaje = a.cod_tip_mensaje
          and b.cod_tip_mensaje not in ('034', '227', '090') -- solo en la nueva web
          and trunc(a.fec_insercion) = trunc(sysdate)
        order by nro_documento;
-- cursor para confirmacion de datos
mp bw_mov_pendientes%rowtype;
-- datos a responder
v_can_detalles   number(3) := 0;
v_detalles        clob := null;   -- datos de las cuentas
v_can_aut_faltantes number(3) := 0;
v_det_confirmacion varchar2(3000);
--- pago de sueldos
v_cod_tra_padre number(4);
v_lugar varchar2(4000);
v_cant_error number(8);
v_TCreCab  number;
v_TCreDet  number;
v_TDebDet  number;
v_cCreDet  number;
v_verificacion_ok varchar2(10);
v_error     varchar2(1000);
v_Reprocesa varchar2(1) := 'N';
v_secuencia number(10) := 1;
v_msj_original varchar2(1000);
v_err_pago  varchar2(2) := '00' ;
v_res_limite varchar2(2); -- para límite de operaciones
v_tip_pro_sueldo varchar2(1);
v_monto ge_movimientos.monto%type;
v_des_monto varchar2(100);
v_pro_con_errores varchar2(1);
--
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. verifico la accion
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     if v_cod_per_empresa is null then
        begin
        select min(cod_per_principal)
          into v_cod_per_empresa   -- esta es una solucion para que los clientes fisicos de cuentas conjuntas puedan autorizarse
          from bw_mov_pendientes a
         where estado = 'P'
           and pag_gen.FU_ES_PER_FISICA(cod_per_principal)='S'
           and cod_per_principal <> v_cod_persona
           and exists (select 0 from ge_cta_clientes b
                        where b.nro_cuenta = a.nro_cuenta
                          and b.cod_persona = v_cod_persona);
        exception
          when others then
             v_cod_per_empresa := null;
        end;
     end if;
     if v_modo = 'S' then
        -- selecciona los movimientos pendientes
        for mp in ope_pend loop
            v_can_detalles := v_can_detalles + 1;
            if mp.cod_modulo = 5 then
               v_cta_formateada := lf_obt_nro_tarjeta(mp.nro_cuenta);
            else
               v_cta_formateada := mp.cta_formateada;
            end if;
            
            if substr(mp.descripcion,0,35)='TRANSFERENCIA INTERBANCARIA OTROS B' then
               v_descripcion:='TRANSFERENCIA A OTROS BANCOS';
            else
                 
                 v_descripcion:=lf_for_char(mp.descripcion,35);
            end if;
            v_detalles := v_detalles ||
                          lf_for_char(mp.nro_documento,15)||
                          lf_for_char(mp.fec_hora,20)||
                          lf_for_char(v_descripcion,35)||
                          lf_for_char(v_cta_formateada,17)||
                          lf_for_char(rpad(mp.cod_moneda,3,'.'),3)||
                          lf_for_money(mp.monto);
        end loop;
     elsif v_modo in ('D','A','R','I') then -- D-DETALLE, A-AUTORIZAR, R-RECHAZAR OPERACION, I-IMPRIMIR
        -- modo visualizar detalles
        v_nro_documento:= nvl(to_number(replace(trim(substr(p_parametros,67,15)),',','.')),0);
        
        -- controlo que el número de documento pertenezca a la empresa    
        if fu_val_per_pendiente(v_nro_documento, v_cod_per_empresa) = 'N' then
          v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
        end if;
        --
        
        -- si no hubo errores se consultan los límites o el detalle
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
          if v_modo = 'D' then
            -- para límite global de operaciones, me dice que pedir al autorizador
            v_res_limite := fu_obt_aut_limite(v_cod_per_empresa, v_nro_documento);
            v_detalles := v_res_limite || fuw_imp_mov_pendiente(v_nro_documento,'S');  -- con el campo comentario           
          else
            v_detalles := fuw_imp_mov_pendiente(v_nro_documento,'N');
          end if;
        end if;
        
        if v_cod_respuesta=paw_bce.v_cod_aprobado then 
           begin
              select *
                into mp
                from bw_mov_pendientes
               where nro_documento = v_nro_documento
                 and cod_per_principal = v_cod_per_empresa
                 and trunc(fec_insercion) = trunc(sysdate);
                 
              v_permiso := lf_obt_permisos(v_cod_per_empresa, v_cod_perfil, mp.cod_tip_mensaje);
              
              if v_permiso is null or (v_modo in ('A', 'R') and 
                                       instr(nvl(v_permiso,'x'),'A') = 0 and 
                                       instr(v_tip_mensaje,'A') > 0) then
                 v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
              end if;
           exception
              when no_data_found then
                 v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
              when others then
                 v_cod_respuesta := paw_bce.v_cod_otr_error;
           end;
        end if;
        
        -- si no hubo errores y es mensaje para autorizar
        if v_modo = 'A' and v_cod_respuesta = paw_bce.v_cod_aprobado then  -- autorizar la transacción
           v_comentario := substr(p_parametros,82,50);  -- comentario ingresado por el cliente
           -- valido que el comentario solo contenga datos alfanuméricos
           v_comentario := lf_obt_alfanumerico(v_comentario, 50);        
           -- 0. Controlo los límites para saber que controlar al autorizador
           v_res_limite := fu_obt_aut_limite(v_cod_per_empresa, v_nro_documento);
           
           if v_cod_respuesta = paw_bce.v_cod_aprobado and v_res_limite in ('10','11') then -- se debe controlar la clave transaccioanl
              v_cod_respuesta :=lf_obt_cla_validar(p_parametros,v_cod_persona,v_cod_per_empresa,132,'T');
           end if;
           
           if v_cod_respuesta = paw_bce.v_cod_aprobado and v_res_limite in ('01','11') then -- se debe controlar la clave token
              v_cod_respuesta :=fu_obt_tok_validar(p_parametros,v_cod_persona,v_cod_per_empresa,164, 'A');
           end if;
           
           -- 1. busco los datos de la operación pendiente        
           if v_cod_respuesta=paw_bce.v_cod_aprobado then 
              begin
                 select *
                   into mp
                   from bw_mov_pendientes
                  where nro_documento = v_nro_documento
                    and cod_per_principal = v_cod_per_empresa
                    and estado = 'P';
              exception
                 when no_data_found then
                     v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
                 when others then
                     v_cod_respuesta := paw_bce.v_cod_otr_error;
              end;
              -- actualizo el movimiento pendiente
              if v_cod_respuesta = paw_bce.v_cod_aprobado then
                 update bw_mov_pendientes
                    set can_aut_faltantes = nvl(can_aut_faltantes,0) - 1,
                        estado = decode(can_aut_faltantes,1,'C',estado)
                  where nro_documento = v_nro_documento
                    and cod_per_principal = v_cod_per_empresa
                  returning can_aut_faltantes into v_can_aut_faltantes;
              end if;
              -- verificamos el saldo disponible para pago de salarios
              if v_cod_respuesta = paw_bce.v_cod_aprobado then
                 if mp.cod_tip_mensaje = '070'  then
                    -- obtenemos el modo de operar cuando hay errores
                    v_pro_con_errores := nvl(TRIM(fug_obt_parentes(mp.dato,'PRO_CON_ERRORES')),'C');
                    -- obtenemos la transacción padre
                    if mp.dato2 = 'S' then
                       v_cod_tra_padre :=fug_obt_parentes(mp.dato, 'COD_TRA_PAD_SUELDO');
                    elsif mp.dato2 = 'A' then
                       v_cod_tra_padre :=fug_obt_parentes(mp.dato, 'COD_TRA_PAD_AGUINALDO');
                    elsif mp.dato2 = 'C' then
                       v_cod_tra_padre :=fug_obt_parentes(mp.dato, 'COD_TRA_PAD_COMISION');
                    elsif mp.dato2 = 'T' then
                       v_cod_tra_padre :=fug_obt_parentes(mp.dato, 'COD_TRA_PAD_CREDITO');
                    end if;                    
                    -- obtenemos el tipo de proceso de sueldo para el ente
                    begin
                       v_tip_pro_sueldo := nvl(fug_obt_parentes(mp.dato, 'TIP_PRO_SUELDO'), 'O');
                    exception
                      when others then
                        v_tip_pro_sueldo := 'O';
                    end;
                    -- si es aguinaldo, procesar en linea y cancelar si hay errores
                    if mp.dato2 = 'A' then
                       v_pro_con_errores := 'C';
                       v_tip_pro_sueldo := 'O';
                    end if;                                    
                    -- verificamos si se puede realizar la operación de débito
                    if fu_ver_operacion(mp.nro_cuenta, mp.monto, 503, v_cod_tra_padre, 'D') = 'N' then
                       if pag_cta.g_cod_error <> 0 then
                          -- controlamos si dispone de saldo suficiente
                          if pag_cta.g_cod_error in (25, 29, 31, 36) then
                             if v_tip_pro_sueldo = 'O' then  -- solo si es online debe dar error por saldo
                                v_cod_respuesta := paw_bce.v_cod_sal_insuficiente;
                             end if;
                          else
                             -- hubo otro error
                             v_cod_respuesta := paw_bce.v_cod_cta_invalida;
                          end if;   
                       end if;
                    end if;
                 end if;
              end if;
              -- inserto el movimiento de autorización
              begin
              insert into bw_autorizaciones
                  (cod_persona,nro_documento, fec_hora, accion, observacion)
              values
                  (v_cod_persona,v_nro_documento, sysdate, 'A', v_comentario);
              exception
                 when dup_val_on_index then
                    v_cod_respuesta := paw_bce.v_cod_ped_duplicado;
              end;
              -->rbenitez, se agrega esto aquí de nuevo para que haga un refresh de la cantidad de autorizaciones
              --registradas, pues en el momento en el que se autoriza por primera vez no refresca y sale 0
              if v_modo = 'D' then
                v_detalles := fuw_imp_mov_pendiente(v_nro_documento,'S');  -- con el campo comentario
              else
                v_detalles := fuw_imp_mov_pendiente(v_nro_documento,'N');
              end if;
           end if;
           --
           --- VERIFICO QUE TIPO DE OPERACION ES LA QUE SE CONFIRMA
           if v_cod_respuesta = paw_bce.v_cod_aprobado and v_can_aut_faltantes = 0 then

               -- si es una operacion de transferencia
               v_can_aut_requeridas := 1; -- esto para permitir debitar a cuentas conjuntas
               if mp.cod_tip_mensaje = '030' then
                 -- Invoco a la transferencia
                 v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                 v_det_confirmacion := fu_pro_operacion_030(p_parametros,
                                                    mp.nro_cuenta,mp.monto,mp.nro_cta_contra,'A',
                                                    mp.cotizacion,mp.mto_contra,mp.cot_contra,
                                                    mp.dato, mp.dato2);
                 -- fin de 030 transferencias
               elsif mp.cod_tip_mensaje = '031' then
                 -- 031 pago de prestamos
                 v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                 v_det_confirmacion := fu_pro_operacion_031(p_parametros,
                                                            mp.nro_cuenta, mp.monto, mp.nro_cta_contra, 'A', mp.dato);

               elsif mp.cod_tip_mensaje = '032' then
                 -- invoco al pago de tarjetas de credito
                 v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                 v_det_confirmacion := fu_pro_operacion_032(p_parametros,
                                                            mp.nro_cuenta, mp.monto, mp.dato, 'A');
               elsif mp.cod_tip_mensaje = '033' then
                 -- invoco al pago de despachos aduaneros
                 -- obtiene el mensaje original de la operacion (
                 begin
                   select parametros
                     into v_msj_original
                     from bw_movimientos
                    where nro_documento = mp.referencia
                      and trunc(fec_hora) = trunc(mp.fec_hora)
                      and cod_tip_mensaje = '033';-- BBVASOP-1357
                 exception
                   when others then
                     v_msj_original := null;
                 end;
                 v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                 v_det_confirmacion := fu_pro_operacion_033(p_parametros,
                                                            mp.nro_cuenta, mp.monto, 'A',v_msj_original);

               -- OMM 09/01/2012 Autorizacion de Transferencia Interbancaria
               elsif mp.cod_tip_mensaje = '036' then
                  -- Invoco a la Transferencia Interbancaria
                  v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                  v_det_confirmacion := fu_pro_operacion_036(p_parametros,
                                                            'A',
                                                             mp.referencia,
                                                             mp.nro_cuenta,
                                                             mp.monto,
                                                             mp.cotizacion,
                                                             mp.nro_cta_contra,
                                                             mp.mto_contra,
                                                             mp.cot_contra,
                                                             substr(mp.dato, instr(mp.dato,'*') + 1),
                                                             to_date(mp.dato2, 'DD/MM/YYYY'));
               -- OMM 30/07/2012 Cancelacion de Transferencia Interbancaria
               elsif mp.cod_tip_mensaje = '038' then
                  -- Invoco a la Transferencia Interbancaria
                  v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                  v_det_confirmacion := fu_pro_operacion_038(p_parametros,
                                                             'A',
                                                             mp.referencia) ;
               elsif mp.cod_tip_mensaje = '039' then
                  -- Invoco a la transferencia a terceros
                  v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                  v_det_confirmacion := fu_pro_operacion_039(p_parametros,
                                                      mp.nro_cuenta,mp.monto,mp.nro_cta_contra,'A',
                                                      mp.cotizacion,mp.mto_contra,mp.cot_contra,
                                                      mp.dato, mp.dato2);
                  -- fin de 039 transferencias  
               elsif mp.cod_tip_mensaje = '060' then
                 -- solicitud de chequeras
                 v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                 v_det_confirmacion := fu_pro_operacion_060(p_parametros,
                                                            mp.nro_cuenta, 'A', substr(mp.dato,1,7), mp.cantidad, substr(mp.dato2,1,3));
               
               elsif mp.cod_tip_mensaje = '214' then
                 -- OMM 03/06/2011 Para Operacion de Cambios con Precio Preferencial
                 v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                 v_det_confirmacion := fu_pro_operacion_214(p_parametros,
                                                    mp.nro_cuenta,mp.monto,mp.nro_cta_contra,'A',
                                                    mp.cotizacion,mp.mto_contra,mp.cot_contra,
                                                    mp.dato, mp.dato2, mp.referencia);                                             
               elsif mp.cod_tip_mensaje = '070' then
                  v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                 /* IF mp.dato2 = 'S' THEN
                     v_cod_tra_padre :=fug_obt_parentes(mp.dato, 'COD_TRA_PAD_SUELDO');
                  ELSIF mp.dato2 = 'A' THEN
                    v_cod_tra_padre :=fug_obt_parentes(mp.dato, 'COD_TRA_PAD_AGUINALDO');
                  ELSIF mp.dato2 = 'C' THEN
                     v_cod_tra_padre :=fug_obt_parentes(mp.dato, 'COD_TRA_PAD_COMISION');
                  ELSIF mp.dato2 = 'T' THEN
                    v_cod_tra_padre :=fug_obt_parentes(mp.dato, 'COD_TRA_PAD_CREDITO');
                  end if;*/
                  
                  if v_tip_pro_sueldo = 'O' then
                    PAG_SUE.PR_INS_GE_PAG_SUELDO(v_verificacion_ok,
                                     mp.dato,
                                     mp.nro_cuenta,
                                     v_cod_tra_padre,
                                     v_fec_actual,
                                     v_lugar,
                                     v_cant_error,
                                     v_TCreCab,
                                     v_TCreDet,
                                     v_TDebDet,
                                     v_cCreDet,
                                     mp.referencia, 
                                     v_cod_usuario, -- JIRA 2376
                                     v_fec_actual, -- jira 2376
                                     mp.dato2); -- 2576

                    IF NVL(v_Cant_Error,0) <> 0 THEN
                      SELECT SUM(monto)
                        INTO v_monto
                        FROM ge_pag_sueldos_tmp
                       WHERE cod_ente = mp.dato
                         AND usu_insercion = v_cod_usuario
                         AND trunc(fec_insercion) = v_fec_actual
                         AND tipo = 'C'
                         AND nro_archivo = mp.referencia;
                      -- verificamos si el ente puede procesar pagos con error
                      if NVL(v_monto,0) <> NVL(v_TDebDet,0) and v_pro_con_errores = 'C' then
                         v_cod_respuesta := paw_bce.v_cod_tra_invalida;
                      end if;
                    END IF;
                    -- IF  NVL(v_Cant_Error,0) = 0 and v_verificacion_ok = 'S' THEN
                    IF v_cod_respuesta = paw_bce.v_cod_aprobado THEN
                      -- no bubo errores
                      v_secuencia := mp.referencia; -- JIRA 2376
                      PAG_SUE.LP_INS_TABLA(mp.dato, v_lugar, v_secuencia, v_error,mp.referencia,
                      v_cod_usuario, sysdate, v_fec_actual, 'N'); -- JIRA 2376
                      IF V_ERROR in ('X', 'S') THEN
                         v_cod_respuesta := paw_bce.v_cod_tra_invalida;
                      ELSE
                        v_nro_secuencia := 0;
                        pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                                                  v_fec_actual,
                                                  v_cod_tra_padre, 'N', 'N',
                                                  v_nro_secuencia,
                                                  null, v_cod_ofi_origen, 3, 31);
                        v_secuencia := mp.referencia; -- JIRA 2376                        
                        -- se puede hacer el credito
                        PAG_SUE.PR_ACT_CRED_EMPLEADO(v_Reprocesa,
                                         mp.dato,
                                         v_secuencia,
                                         v_cod_ofi_origen,
                                         v_fec_actual,
                                         v_cod_usuario,
                                         v_lugar,
                                         v_error,
                                        mp.dato2);
                      END IF;
                    ELSE -- hubo error en la verificacion
                      v_cod_respuesta := paw_bce.v_cod_tra_invalida;
                    END IF;
                  else 
                    declare
                      v_nro_secuencia number := mp.referencia;
                    begin
                      insert into ge_pag_sue_lotes 
                        (cod_ente, fec_proceso, nro_secuencia, nro_cta_debito, mto_credito, 
                         mto_debito, cod_moneda, cantidad, estado, tip_pago, tip_ingreso, tip_proceso)
                     values 
                        (mp.dato, v_fec_actual, v_nro_secuencia, mp.nro_cuenta, mp.monto,
                         mp.monto, mp.cod_moneda, mp.cantidad, 'P', mp.dato2, 'H', v_tip_pro_sueldo );
                    exception 
                      when others then
                        v_cod_respuesta := paw_bce.v_cod_otr_error;
                        v_error := 'S';
                    end;                    
                  end if;
                  IF V_ERROR in ('X', 'S') THEN
                     v_cod_respuesta := paw_bce.v_cod_tra_invalida;
                  else
                     declare
                         v_des_ente   varchar2(300);
                         v_dir_correo ge_par_dinamicos.val_parametro%type;
                      begin
                         begin
                           v_dir_correo := nvl(fug_obt_pardinamico('SUE_DIR_CORREO'), fug_obt_pardinamico('CAM_MAR_PAG_NOM'));
                         exception 
                           when others then
                             v_dir_correo := fug_obt_pardinamico('CAM_MAR_PAG_NOM');
                         end;   
                      
                        v_des_ente:= fue_obt_nom_ente(mp.dato);

                        if NVL(v_monto,0) <> NVL(V_TDEBDET,0) and
                           nvl(fug_obt_parentes(mp.dato,'PRO_CON_ERRORES'),'C') = 'N' then
                           v_des_monto :=  'Monto Debitado  : ' || lf_for_money(v_monto, 16)|| chr(10) ||
                                           'Monto Solicitado: ' || lf_for_money(V_TDEBDET, 16);
                           -- obtenemos los registros con error para mostrar en el detalle
                           v_detalles := v_detalles||fuw_imp_sue_errores(mp.dato, mp.referencia);
                        else
                           v_des_monto := 'Monto   : ' || lf_for_money(mp.monto, 16);
                        end if;

                        it_mail.mail(fug_obt_dir_correo,
                        v_dir_correo,
                        'Pago de Sueldos Confirmado',
                        'Pago de Sueldos ingresado por HomeBanking ha sido confirmado por el Cliente '|| chr(10) ||
                        'Codigo  : ' || mp.dato|| chr(10) ||
                        'Empresa : ' || v_des_ente|| chr(10) ||
                        v_des_monto  || chr(10) ||
                        'Cantidad: ' || to_char(mp.cantidad) || chr(10) ||
                        'Atentamente. '
                        );
                      exception
                         when others then null;
                      end;
                  end if;
               elsif mp.cod_tip_mensaje = '075' then  -- pago a proveedores
                  declare
                     v_fec_pago1 date    := to_date(substr(mp.dato2,1,10),'dd/mm/yyyy');
                     v_cam_fecha boolean := false;
                  begin
                     -- CR verifico la hora de cierre 
                     v_cam_fecha := fu_ver_hor_cie_proveedor(v_fec_pago1);
                     --
                     
                     pag_prv.PR_VER_DAT_TMP(mp.dato, v_fec_pago1,
                                            to_date(substr(mp.dato2,12,10),'dd/mm/yyyy'), v_error, 'S', mp.nro_documento, mp.nro_cuenta, mp.referencia);
                     if v_error is not null then
                        v_cod_respuesta := paw_bce.v_cod_cta_duplicada;
                        -- raise_application_error(-20000,v_error);
                     else
                      declare
                         v_des_ente varchar2(300);
                       begin
                          select descripcion
                            into v_des_ente
                            from ge_entes
                           where cod_ente = to_number(mp.dato);
                          if v_fec_pago1 = trunc(sysdate) then
                             pag_prv.PR_PRO_PAGO(to_number(mp.dato), mp.nro_documento, v_err_pago);
                             if v_err_pago <> '00' then
                                 v_cod_respuesta := v_err_pag_prov ;
                             else
                                it_mail.mail(fug_obt_dir_correo,
                                        fug_obt_pardinamico('CAM_MAR_PAG_NOM'),
                                        'Pago a Proveedores en Linea',
                                        'Pago a Proveedores ingresado por el HomeBanking '|| chr(10) ||chr(10) ||
                                        'Codigo  : ' || mp.dato|| chr(10) ||
                                        'Empresa : ' || v_des_ente|| chr(10) ||
                                        'Monto   : ' || lf_for_money(mp.monto, 16)|| chr(10) ||
                                        'Cantidad: ' || to_char(mp.cantidad) || chr(10) ||
                                        'Fecha de Pago: ' || to_char(v_fec_pago1, 'dd/mm/yyyy') || chr(10) ||chr(10) ||
                                        'Atentamente. '
                                        );
                              end if ;
                           else
                              it_mail.mail( fug_obt_dir_correo,
                                  fug_obt_pardinamico('CAM_MAR_PAG_NOM'),
                                  'Pago a Proveedores en Fecha Futura',
                                  'Pago a Proveedores ingresado por el HomeBanking '|| chr(10) ||chr(10) ||
                                  'Codigo  : ' || mp.dato|| chr(10) ||
                                  'Empresa : ' || v_des_ente|| chr(10) ||
                                  'Monto   : ' || lf_for_money(mp.monto, 16)||chr(10)||
                                  'Cantidad: ' || to_char(mp.cantidad) || chr(10) ||
                                  'Fecha de Pago: ' || to_char(v_fec_pago1, 'dd/mm/yyyy') || chr(10) ||chr(10) ||
                                  'Atentamente. '
                                  );
                           end if ;
                           
                           -- CR actualizamos el cambio de fecha en la tabla de movimientos pendientes
                           if v_cam_fecha = true then
                             pr_act_fec_pag_pendiente(v_nro_documento, 
                                                      v_cod_per_empresa,
                                                      to_char(v_fec_pago1,'dd/mm/yyyy')||' '||substr(mp.dato2,12,10));
                           end if;
                           --
                           
                           if v_cod_respuesta = paw_bce.v_cod_aprobado then
                             pag_prv.PR_ELI_PROV_TMP(mp.dato, sysdate/*, mp.referencia*/);
                             pag_prv.PR_ELI_FAC_TMP(mp.dato/*, sysdate, mp.referencia*/);
                           end if;
                       exception
                         when others then null;
                        end;
                     End if;
                  end;
               end if;
           end if;
           -- fin de la confirmacion de operaciones
           -- registro del movimiento
           lp_reg_operacion(null /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Nro.Documento' /*p_etiqueta*/,
                   v_nro_documento /*p_dato*/,
                   'Accion',
                   v_modo,
                   v_comentario
                 );
           -- respuesta lleva siempre cuantas autorizaciones faltan
           return lf_for_number(v_can_aut_faltantes,3)||v_detalles;
        elsif v_modo = 'R' and v_cod_respuesta = paw_bce.v_cod_aprobado then -- rechazo si no hubo error
           -- anular la operacion
           v_comentario := substr(p_parametros,82, 50);
           -- valido que el comentario solo contenga datos alfanuméricos
           v_comentario := lf_obt_alfanumerico(v_comentario, 50);
           -- 0. Controlo los límites para saber que controlar al autorizador
           v_res_limite := fu_obt_aut_limite(v_cod_per_empresa, v_nro_documento);
           
           if v_cod_respuesta = paw_bce.v_cod_aprobado and v_res_limite in ('10','11') then -- se debe controlar la clave transaccioanl
              v_cod_respuesta :=lf_obt_cla_validar(p_parametros,v_cod_persona,v_cod_per_empresa,132, 'T');
           end if;
           
           if v_cod_respuesta = paw_bce.v_cod_aprobado and v_res_limite in ('01','11') then -- se debe controlar la clave token
              v_cod_respuesta :=fu_obt_tok_validar(p_parametros,v_cod_persona,v_cod_per_empresa,164, 'A');
           end if;
           -- 1. busco los datos de la operacion pendiente
           begin
              select *
                into mp
                from bw_mov_pendientes
               where nro_documento = v_nro_documento
                 and cod_per_principal = v_cod_per_empresa
                 and estado = 'P';
           exception
              when no_data_found then
                  v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
              when others then
                  v_cod_respuesta := paw_bce.v_cod_otr_error;
           end;
           
           -- si no hubo errores, elimino los temporales
           if v_cod_respuesta = paw_bce.v_cod_aprobado then
              if mp.cod_tip_mensaje = '036' then
                 Begin
                    Update ge_snp_transferencias gs
                       set gs.estado = 'C'
                     where gs.nro_referencia = mp.referencia ;
                 exception
                    when others then
                       v_cod_respuesta := paw_bce.v_cod_tra_invalida ;
                 end ;
              elsif  mp.cod_tip_mensaje = '070' then
               -- Al anular debe borrar en ge_pag_sueldos_tmp.
               pag_sue.LP_DEL_DATOS_TEMPORA(mp.dato, v_fec_actual, v_lugar, mp.referencia);
             elsif mp.cod_tip_mensaje = '075' then
               -- borro los movimientos pendientes
               pag_prv.PR_ELI_PROV_TMP(mp.dato, sysdate/*, mp.referencia*/);
               pag_prv.PR_ELI_FAC_TMP(mp.dato/*, sysdate, mp.referencia*/);
             end if;
           end if;

           -- actualizo a anulada la operacion pendiente
           update bw_mov_pendientes
              set estado = 'A' -- ANULADA
            where nro_documento = v_nro_documento
              and cod_per_principal = v_cod_per_empresa;
           
           -- si no hubo errores
           if v_cod_respuesta = paw_bce.v_cod_aprobado then
             begin
               -- inserto el movimiento por la anulacion
               insert into bw_autorizaciones
                  (cod_persona,nro_documento, fec_hora, accion, observacion)
               values
                  (v_cod_persona,v_nro_documento, sysdate, 'R', v_comentario);
             exception
               when dup_val_on_index then
                 v_cod_respuesta := paw_bce.v_cod_ped_duplicado;
             end;
           end if;
           -- fin de la anulacion
           -- registro del movimiento
           lp_reg_operacion(null /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Nro.Documento' /*p_etiqueta*/,
                   v_nro_documento /*p_dato*/,
                   'Accion',
                   v_modo,
                   v_comentario
                 );
        end if;
        return lf_for_number(v_can_aut_faltantes,3)||v_detalles;
     end if;
     if v_can_detalles = 0  then
        -- no tiene cotizaciones
         v_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
     end if;
  end if;
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return lf_for_number(v_can_detalles,3)||
            v_detalles;
  else
     return null;  -- nada
  end if;

end;
-- fin de 023- Consulta y confirmacion de autorizaciones pendientes

-- 024- Consulta  de autorizaciones pendientes
function fu_pro_operacion_024(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_modo            varchar2(3) := substr(p_parametros,66,1);   -- modo S/V/C
v_nro_documento   number(15);
v_comentario      varchar(200);
--- datos internos
---
v_cta_formateada varchar2(20);
cursor ope_pend is
       select a.nro_documento, to_char(a.fec_hora,'DD/MM/YYYY HH24:MI:SS') fec_hora, b.descripcion,
              fug_cta_formateada(c.cod_modulo, c.cod_modalidad, c.cod_oficina,c.nro_cuenta, c.cod_moneda) cta_formateada,
              a.nro_cuenta, a.cod_moneda, a.monto, c.cod_modulo,
              decode(a.estado,'A','Anulada','C','Confirmada','P','Pendiente') estado,
              a.referencia
         from ge_cuentas c, bw_tip_mensajes b, bw_mov_pendientes a
        where a.cod_per_principal = v_cod_per_empresa
          and c.nro_cuenta = a.nro_cuenta
          and b.cod_tip_mensaje = a.cod_tip_mensaje
          and trunc(a.fec_insercion) = trunc(sysdate)
        order by nro_documento;
-- cursor para confirmacion de datos
mp bw_mov_pendientes%rowtype;
-- datos a responder
v_can_detalles   number(3) := 0;
v_detalles        clob := null;   -- datos de las cuentas
v_can_aut_faltantes number(3) := 0;
v_det_confirmacion varchar2(3000);
--- pago de sueldos
v_cod_tra_padre number(4);
v_lugar varchar2(4000);
v_cant_error number(8);
v_TCreCab  number;
v_TCreDet  number;
v_TDebDet  number;
v_cCreDet  number;
v_verificacion_ok varchar2(10);
v_error     varchar2(1000);
v_Reprocesa varchar2(1) := 'N';
v_secuencia number(10) := 1;
v_msj_original varchar2(1000);
---
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. verifico la accion
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     if v_cod_per_empresa is null then
        begin
        select min(cod_per_principal)
          into v_cod_per_empresa   -- esta es una solucion para que los clientes fisicos de cuentas conjuntas puedan autorizarse
          from bw_mov_pendientes a
         where estado = 'P'
           and pag_gen.FU_ES_PER_FISICA(cod_per_principal)='S'
           and cod_per_principal <> v_cod_persona
           and exists (select 0 from ge_cta_clientes b
                        where b.nro_cuenta = a.nro_cuenta
                          and b.cod_persona = v_cod_persona);
        exception
          when others then
             v_cod_per_empresa := null;
        end;
     end if;
     if v_modo = 'S' then
        -- selecciona los movimientos pendientes
        for mp in ope_pend loop
            v_can_detalles := v_can_detalles + 1;
            if mp.cod_modulo = 5 then
               v_cta_formateada := lf_obt_nro_tarjeta(mp.nro_cuenta);
            else
               v_cta_formateada := mp.cta_formateada;
            end if;
            v_detalles := v_detalles ||
                          lf_for_char(mp.nro_documento,15)||
                          lf_for_char(mp.fec_hora,20)||
                          lf_for_char(mp.descripcion,35)||
                          lf_for_char(v_cta_formateada,17)||
                          lf_for_char(rpad(mp.cod_moneda,3,'.'),3)||
                          lf_for_money(mp.monto)||
                          lf_for_char(mp.estado,10);
        end loop;
     elsif v_modo in ('D','A','R','I') then -- D-DETALLE, A-AUTORIZAR, R-RECHAZAR OPERACION, I-IMPRIMIR
        -- modo visualizar detalles
        v_nro_documento:= nvl(to_number(replace(trim(substr(p_parametros,67,15)),',','.')),0);
        
        -- controlo que el número de documento pertenezca a la empresa        
        if fu_val_per_pendiente(v_nro_documento, v_cod_per_empresa) = 'N' then
          v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
        end if;
        
        -- si no hubo errores, muestro el detalle
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
          if v_modo = 'D' then
            v_detalles := fuw_imp_mov_pendiente(v_nro_documento,'N', 'N');  -- con el campo comentario
          else
            v_detalles := fuw_imp_mov_pendiente(v_nro_documento,'N', 'N');
          end if;
        end if;
        --
        if v_cod_respuesta=paw_bce.v_cod_aprobado then 
           begin
              select *
                into mp
                from bw_mov_pendientes
               where nro_documento = v_nro_documento
                 and cod_per_principal = v_cod_per_empresa
                 and trunc(fec_insercion) = trunc(sysdate);
                 
              v_permiso := lf_obt_permisos(v_cod_per_empresa, v_cod_perfil, mp.cod_tip_mensaje);
              
              if v_permiso is null or (v_modo in ('A', 'R') and 
                                       instr(nvl(v_permiso,'x'),'A') = 0 and 
                                       instr(v_tip_mensaje,'A') > 0) then
                 v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
              end if;
           exception
              when no_data_found then
                 v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
              when others then
                 v_cod_respuesta := paw_bce.v_cod_otr_error;
           end;
        end if;
        if v_modo = 'A' and v_cod_respuesta = paw_bce.v_cod_aprobado then  -- autorizar la transaccion
           v_comentario := substr(p_parametros,82, 50);  -- comentario ingresado por el cliente
           -- valido que el comentario solo contenga datos alfanuméricos
           v_comentario := lf_obt_alfanumerico(v_comentario, 50);
           -- 1. busco los datos de la operacion pendiente
           begin
              select *
                into mp
                from bw_mov_pendientes
               where nro_documento = v_nro_documento
                 and cod_per_principal = v_cod_per_empresa
                 and estado = 'P';
           exception
              when no_data_found then
                  v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
              when others then
                  v_cod_respuesta := paw_bce.v_cod_otr_error;
           end;
           -- actualizo el movimiento pendiente
           update bw_mov_pendientes
              set can_aut_faltantes = nvl(can_aut_faltantes,0) - 1,
                  estado = decode(can_aut_faltantes,1,'C',estado)
            where nro_documento = v_nro_documento
              and cod_per_principal = v_cod_per_empresa
            returning can_aut_faltantes into v_can_aut_faltantes;
           -- inserto el movimiento de autorizacion
           begin
           insert into bw_autorizaciones
               (cod_persona,nro_documento, fec_hora, accion, observacion)
           values
               (v_cod_persona,v_nro_documento, sysdate, 'A', v_comentario);
           exception
              when dup_val_on_index then
                 v_cod_respuesta := paw_bce.v_cod_ped_duplicado;
           end;
           --- VERIFICO QUE TIPO DE OPERACION ES LA QUE SE CONFIRMA
           if v_cod_respuesta = paw_bce.v_cod_aprobado and v_can_aut_faltantes = 0 then
               -- si es una operacion de transferencia
               v_can_aut_requeridas := 1; -- esto para permitir debitar a cuentas conjuntas
               if mp.cod_tip_mensaje = '030' then
                 -- Invoco a la transferencia
                 v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                 v_det_confirmacion := fu_pro_operacion_030(p_parametros,
                                                    mp.nro_cuenta,mp.monto,mp.nro_cta_contra,'A',
                                                    mp.cotizacion,mp.mto_contra,mp.cot_contra,
                                                    mp.dato);
                 -- fin de 030 transferencias
               elsif mp.cod_tip_mensaje = '031' then
                 -- 031 pago de prestamos
                 v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                 v_det_confirmacion := fu_pro_operacion_031(p_parametros,
                                                            mp.nro_cuenta, mp.monto, mp.nro_cta_contra, 'A', mp.dato);

               elsif mp.cod_tip_mensaje = '032' then
                 -- invoco al pago de tarjetas de credito
                 v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                 v_det_confirmacion := fu_pro_operacion_032(p_parametros,
                                                            mp.nro_cuenta, mp.monto, mp.dato, 'A');
               elsif mp.cod_tip_mensaje = '033' then
                 -- obtiene el mensaje original de la operacion (TYS 23-11-07)
                 begin
                   select parametros
                     into v_msj_original
                     from bw_movimientos
                    where nro_documento = mp.referencia
                      and trunc(fec_hora) = trunc(mp.fec_hora)
                      and cod_tip_mensaje = '033';-- BBVASOP-1357
                 exception
                   when others then
                     v_msj_original := null;
                 end;
                 -- invoco al pago de despachos aduaneros
                 v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                 v_det_confirmacion := fu_pro_operacion_033(p_parametros,
                                                            mp.nro_cuenta, mp.monto, 'A', v_msj_original);
               elsif mp.cod_tip_mensaje = '060' then
                 -- solicitud de chequeras
                 v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                 v_det_confirmacion := fu_pro_operacion_060(p_parametros,
                                                            mp.nro_cuenta, 'A', substr(mp.dato,1,7), mp.cantidad, substr(mp.dato2,1,3));
               elsif mp.cod_tip_mensaje = '070' then
                  v_nro_operacion := mp.nro_documento; -- cambio el nro de operacion
                  IF mp.dato2 = 'S' THEN
                     v_cod_tra_padre :=fug_obt_parentes(mp.dato, 'COD_TRA_PAD_SUELDO');
                  ELSIF mp.dato2 = 'A' THEN
                    v_cod_tra_padre :=fug_obt_parentes(mp.dato, 'COD_TRA_PAD_AGUINALDO');
                  ELSIF mp.dato2 = 'C' THEN
                     v_cod_tra_padre :=fug_obt_parentes(mp.dato, 'COD_TRA_PAD_COMISION');
                  ELSIF mp.dato2 = 'T' THEN
                    v_cod_tra_padre :=fug_obt_parentes(mp.dato, 'COD_TRA_PAD_CREDITO');
                  end if;

                   PAG_SUE.PR_INS_GE_PAG_SUELDO(v_verificacion_ok,
                                     mp.dato,
                                     mp.nro_cuenta,
                                     v_cod_tra_padre,
                                     v_fec_actual,
                                     v_lugar,
                                     v_cant_error,
                                     v_TCreCab,
                                     v_TCreDet,
                                     v_TDebDet,
                                     v_cCreDet,
                                     mp.dato2);

                  IF  NVL(v_Cant_Error,0) = 0 and v_verificacion_ok = 'S' THEN
                      -- no bubo errores
                      PAG_SUE.LP_INS_TABLA(mp.dato, v_lugar, v_secuencia, v_error, mp.referencia,
                                           v_cod_usuario, sysdate, v_fec_actual, 'N');
                      IF V_ERROR in ('X', 'S') THEN
                         --v_cod_respuesta := paw_bce.v_cod_otr_error;
                         v_cod_respuesta := paw_bce.v_cod_sal_insuficiente;
                         -- raise_application_error(-20005,'Insertando '||sqlerrm);
                      else
                        v_nro_secuencia := 0;
                        pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                                                  v_fec_actual,
                                                  v_cod_tra_padre, 'N', 'N',
                                                  v_nro_secuencia,
                                                  null, v_cod_ofi_origen, 3, 31);
                        -- se puede hacer el credito
                        PAG_SUE.PR_ACT_CRED_EMPLEADO(v_Reprocesa,
                                         mp.dato,
                                         v_secuencia,
                                         v_cod_ofi_origen,
                                         v_fec_actual,
                                         v_cod_usuario,
                                         v_lugar,
                                         v_error,
                                        mp.dato2);
                      end if;
                  else -- hubo error en la verificacion
                      --v_cod_respuesta := paw_bce.v_cod_otr_error;
                      v_cod_respuesta := paw_bce.v_cod_sal_insuficiente;
                      ---raise_application_error(-20005,'Acreditando '||v_cant_error||' ver '||v_verificacion_ok||' - ' ||sqlerrm);
                  end if;
                  IF V_ERROR in ('X', 'S') THEN
                     --v_cod_respuesta := paw_bce.v_cod_otr_error;
                     v_cod_respuesta := paw_bce.v_cod_sal_insuficiente;
                  else
                     declare
                         v_des_ente varchar2(300);
                      begin
                          select descripcion
                            into v_des_ente
                            from ge_entes
                           where cod_ente = to_number(mp.dato);
                        it_mail.mail(fug_obt_dir_correo,
                        fug_obt_pardinamico('DIR_CORREO_SALARIOS'),
                        'Pago de Sueldos Confirmado',
                        'Pago de Sueldos ingresado por HomeBanking ha sido confirmado por el Cliente '|| chr(10) ||
                        'Codigo  : ' || mp.dato|| chr(10) ||
                        'Empresa : ' || v_des_ente|| chr(10) ||
                        'Monto   : ' || lf_for_money(mp.monto, 16)|| chr(10) ||
                        'Cantidad: ' || to_char(mp.cantidad) || chr(10) ||
                        'Atentamente. '
                        );
                      exception
                         when others then null;
                      end;
                  end if;
               elsif mp.cod_tip_mensaje = '075' then  -- pago a proveedores
                  begin
                     pag_prv.PR_VER_DAT_TMP(mp.dato, to_date(substr(mp.dato2,1,10),'dd/mm/yyyy'),
                                            to_date(substr(mp.dato2,12,10),'dd/mm/yyyy'), v_error, 'S', mp.nro_documento, mp.nro_cuenta, mp.referencia);
                     if v_error is not null then
                        --v_cod_respuesta := paw_bce.v_cod_cta_duplicada;
                        raise_application_error(-20000,v_error);
                     else
                      declare
                         v_des_ente varchar2(300);
                      begin
                          select descripcion
                            into v_des_ente
                            from ge_entes
                           where cod_ente = to_number(mp.dato);
                          it_mail.mail(fug_obt_dir_correo,
                                        fug_obt_pardinamico('DIR_CORREO_SALARIOS'),
                                        'Pago a Proveedores',
                                        'Pago a Proveedores ingresado por el HomeBanking '|| chr(10) ||
                                        'Codigo  : ' || mp.dato|| chr(10) ||
                                        'Empresa : ' || v_des_ente|| chr(10) ||
                                        'Monto   : ' || lf_for_money(mp.monto, 16)|| chr(10) ||
                                        'Cantidad: ' || to_char(mp.cantidad) || chr(10) ||
                                        'Atentamente. '
                                        );
                      exception
                         when others then null;
                      end;
                     End if;
                  end;
               end if;
           end if;
           -- fin de la confirmacion de operaciones
           -- registro del movimiento
           lp_reg_operacion(null /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Nro.Documento' /*p_etiqueta*/,
                   v_nro_documento /*p_dato*/,
                   'Accion',
                   v_modo,
                   v_comentario
                 );
           -- respuesta lleva siempre cuantas autorizaciones faltan
           return lf_for_number(v_can_aut_faltantes,3)||v_detalles;
        elsif v_modo = 'R' and v_cod_respuesta = v_cod_aprobado then
           -- anular la operacion
           v_comentario := substr(p_parametros,82, 50);
           -- valido que el comentario solo contenga datos alfanuméricos
           v_comentario := lf_obt_alfanumerico(v_comentario, 50);
           -- 1. busco los datos de la operacion pendiente
           begin
              select *
                into mp
                from bw_mov_pendientes
               where nro_documento = v_nro_documento
                 and cod_per_principal = v_cod_per_empresa
                 and estado = 'P';
           exception
              when no_data_found then
                  v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
              when others then
                  v_cod_respuesta := paw_bce.v_cod_otr_error;
           end;
           
           -- si no hubo errores elimino los temporales
           if v_cod_respuesta = paw_bce.v_cod_aprobado then
             if mp.cod_tip_mensaje = '070' then
               -- Al anular debe borrar en ge_pag_sueldos_tmp.
               pag_sue.LP_DEL_DATOS_TEMPORA(mp.dato, v_fec_actual, v_lugar);
             elsif mp.cod_tip_mensaje = '075' then
               -- borro los movimientos pendientes
               pag_prv.PR_ELI_PROV_TMP(mp.dato, sysdate, mp.referencia);
               pag_prv.PR_ELI_FAC_TMP(mp.dato, sysdate, mp.referencia);
             end if;
           end if;

           -- actualizo a anulada la operacion pendiente
           update bw_mov_pendientes
              set estado = 'A' -- ANULADA
            where nro_documento = v_nro_documento
              and cod_per_principal = v_cod_per_empresa;
             
           -- si no hubo errores 
           if v_cod_respuesta = paw_bce.v_cod_aprobado then
             -- inserto el movimiento por la anulacion
             begin
               insert into bw_autorizaciones
                  (cod_persona,nro_documento, fec_hora, accion, observacion)
               values
                  (v_cod_persona,v_nro_documento, sysdate, 'R', v_comentario);
             exception
               when dup_val_on_index then
                 v_cod_respuesta := paw_bce.v_cod_ped_duplicado;
             end;
           end if;
           -- fin de la anulacion
           -- registro del movimiento
           lp_reg_operacion(null /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Nro.Documento' /*p_etiqueta*/,
                   v_nro_documento /*p_dato*/,
                   'Accion',
                   v_modo,
                   v_comentario
                 );
        end if;
        return lf_for_number(v_can_aut_faltantes,3)||v_detalles;
     end if;
     if v_can_detalles = 0  then
        -- no tiene cotizaciones
         v_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
     end if;
  end if;
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return lf_for_number(v_can_detalles,3)||
            v_detalles;
  else
     return null;  -- nada
  end if;

end;
-- fin de 024- Consulta  de autorizaciones pendientes

-- 025- Impresion de Facturas
function fu_pro_operacion_025(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_modo            varchar2(3) := substr(p_parametros,66,1);   -- modo S/V/C
v_nro_factura     varchar2(16) := replace(replace(trim(substr(p_parametros,67)),chr(13),''),chr(10),'');
v_can_detalles    number(3) := 0;
---
cursor facturas is
  select nro_factura, x.fecha,
         decode(x.tip_comprobante,'F','Factura','N','Nota de Credito',null) tipo, nvl(x.cod_moneda,'GS') cod_moneda,
         nvl(x.mto_exento_gs,0) + nvl(x.mto_gravado_5_gs,0) + nvl(x.mto_gravado_10_gs,0) tot_factura,
         nvl(x.impuesto_5_gs,0)+ nvl(x.impuesto_10_gs,0) tot_iva
    from cb_lib_ventas x
   where x.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
     and x.fecha > last_day(add_months(v_fec_actual,-7))
   order by x.fecha;
v_detalles        clob := null;   -- datos de las facturas
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. ejecuto la funcion para generar el comprobante
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if v_modo = 'S' then
      -- despliego las facturas pendientes
      for ft in facturas loop
         v_can_detalles:=v_can_detalles+1;
         v_detalles := v_detalles||
                       lf_for_char(ft.nro_factura,20)||
                       lf_for_date(ft.fecha)||
                       lf_for_char(ft.tipo,20)||
                       lf_for_char(ft.cod_moneda,3)||
                       lf_for_money(ft.tot_factura)||
                       lf_for_money(ft.tot_iva);

      end loop;
      v_detalles := lf_for_number(v_can_detalles,3)||
                    v_detalles;
    elsif v_nro_factura is not null then
       -- ya se que factura imprimir
       if v_nro_factura like ('PENDIENTE%') then
          v_detalles := fuw_imp_factura(nvl(v_cod_per_empresa,v_cod_persona));
       else
          v_detalles := fuw_imp_factura(nvl(v_cod_per_empresa,v_cod_persona),v_nro_factura);
       end if;

    end if;
  end if;
  -- registro del movimiento
  lp_reg_operacion(null /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Nro.Factura' /*p_etiqueta*/,
                   v_nro_factura /*p_dato*/
                 );
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return v_detalles;
  else
     return null;  -- nada
  end if;
end;
-- fin de 025- Impresion de Facturas.


-- 030-validacion o confirmacion de transferencia entre cuentas
function fu_pro_operacion_030(p_parametros      in varchar2,
                              p_nro_cta_debito  in varchar2 default null,
                              p_monto           in number   default null,
                              p_nro_cta_credito in varchar2 default null,
                              p_modo            in varchar2 default null,
                              p_cotizacion      in number   default null,
                              p_mto_credito     in number   default null,
                              p_cot_credito     in number   default null,
                              p_nro_doc_credito in varchar2 default null,
                              p_concepto        in varchar2 default null
  )
  return varchar2 is
-- datos recibidos
v_nro_cta_debito  varchar2(16);
v_monto           number(18,2);   -- monto a transferir
v_nro_cta_credito varchar2(17);   -- cuenta de credito
v_modo            varchar2(1);    -- modo V-validacion o C-confirmacion
-- variables
v_cta_for_debito  varchar2(17);  -- cuenta formateada
v_cod_mon_debito  varchar2(3);   -- moneda de la cuenta
v_est_cta_debito  varchar2(1);   -- estado de la cuenta
v_cod_mod_debito  number(4);     -- modulo de la cuenta
v_cod_mad_debito  number(4);     -- modalidad de la cuenta
v_cod_ofi_debito  number(4);     -- oficina de la cuenta
v_nvo_est_debito  varchar2(1) := null; -- cambio de estado de cuenta
v_cot_debito      number(18,2) := null;
v_nom_cta_debito  varchar2(100);

v_cod_mon_credito  varchar2(3);   -- moneda de la cuenta
v_cta_for_credito  varchar2(17);  -- cuenta formateada
v_est_cta_credito  varchar2(1);   -- estado de la cuenta
v_cod_mod_credito  number(4);     -- modulo de la cuenta
v_cod_mad_credito  number(4);     -- modalidad de la cuenta
v_cod_ofi_credito  number(4);     -- oficina de la cuenta
v_nvo_est_credito  varchar2(1) := null; -- cambio de estado de cuenta
v_sal_dis_credito  number(18,2);
v_mto_credito      number(18,2) := v_monto;
v_cot_credito      number(18,4) := null;
v_nom_cta_credito  varchar2(100);
v_mto_equ_local    number(18) := null;

v_cod_tra_padre   number(4)  := 388;     -- cod. transaccion padre
v_procesa         varchar2(1) := 'N';    -- indica si se puede o no procesar
v_cotizacion      number(18,2) := null;
v_nro_documento   number(15);
v_nro_doc_credito varchar2(20) := null;  -- nro de documento del acreditado
v_concepto        varchar2(100);
v_res_limite      varchar2(2); -- para límite de operaciones
v_res_notificacion number(3); --Respuesta de notificacion
begin
  -- 0. inicializo la secuencia
  v_nro_secuencia := 0;
  if nvl(p_modo,'x') = 'A' then
     -- viene de confirmación de una autorización
     v_nro_cta_debito  := p_nro_cta_debito;
     v_monto           := p_monto;
     v_nro_cta_credito := p_nro_cta_credito;
     v_modo            := p_modo;
     v_cotizacion      := p_cotizacion;
     v_mto_credito     := p_mto_credito;
     v_cot_debito      := p_cotizacion;
     v_cot_credito     := p_cot_credito;
     v_nro_doc_credito := p_nro_doc_credito;
     v_concepto        := p_concepto;
  else
     v_nro_cta_debito  := lf_obt_cta_limpia(trim(substr(p_parametros,66,16)));
     v_monto           := nvl(to_number(replace(trim(substr(p_parametros,82,16)),',','.')),0);   -- monto a transferir
     v_nro_cta_credito := lf_obt_cta_limpia(trim(substr(p_parametros,98,16)));   -- cuenta de crédito
     v_modo            := substr(p_parametros,114,1);    -- modo V-validación o C-confirmación
     if length(p_parametros) > 115 then
        -- nro de documento del acreditado
        v_nro_doc_credito := trim(replace(replace(substr(p_parametros,115,16),chr(13),''),chr(10),''));
     end if;
     if length(p_parametros) > 131 then
        v_concepto := trim(replace(replace(substr(substr(p_parametros,131),1,35),chr(13),''),chr(10),''));
        v_concepto := lf_obt_alfanumerico(v_concepto, 35);
     end if;
     -- 1. valido la clave del cliente
     pr_val_clave(p_parametros);
     if v_modo = 'C' and v_can_aut_requeridas = 0 then
        -- se confirma directamente la operación, porque no requiere autorización
        v_modo := 'A'; -- CONFIRMACIÓN
     end if;
  end if;
  --Verifica los permisos  
  if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(p_modo,'x') <> 'A' then
     v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '030');
     if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
        v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
     end if;
  end if;      
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
      -- verifico cuenta de débito
      if v_nro_cta_debito = v_nro_cta_credito then
         --raise_application_error(-20005,' Cta debito '||v_nro_cta_debito||' Cta Credito '||v_nro_cta_credito);
         v_cod_respuesta := paw_bce.v_cod_tra_invalida;
      else
        pr_val_cta_debito( v_nro_cta_debito,
                           v_cod_tra_padre,
                           v_monto,
                           v_cod_mon_debito,
                           v_cod_mod_debito,
                           v_cod_mad_debito,
                           v_cod_ofi_debito,
                           v_cta_for_debito,
                           v_nom_cta_debito);
        if v_modo = 'C' and v_can_aut_requeridas = 0 then
          -- se confirma directamente la operación, porque no requiere autorización
          v_modo := 'A'; -- CONFIRMACIÓN
        end if;
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
           if lf_val_cta_origen(v_nro_cta_debito,nvl(v_cod_per_empresa,v_cod_persona)) = 'N' then
              -- no es una cuenta del cliente
              v_cod_respuesta := paw_bce.v_cod_cta_invalida;
           end if;
        end if;
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
             --Solamente cuentas de la misma persona
           if lf_val_cta_origen(v_nro_cta_credito, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' then
                -- no es una cuenta del cliente
                v_cod_respuesta := paw_bce.v_cod_cta_invalida;
           end if;
        end if;
      end if;
     if v_cod_respuesta = paw_bce.v_cod_aprobado then
        -- cuenta de credito
        begin
            select a.cod_moneda, a.estado, cod_modalidad,
                   cod_modulo, cod_oficina,
                   fug_cta_formateada(cod_modulo, cod_modalidad, cod_oficina,nro_cuenta, cod_moneda) cta_formateada,
                   denominacion
              into v_cod_mon_credito,
                   v_est_cta_credito, v_cod_mad_credito,
                   v_cod_mod_credito, v_cod_ofi_credito,
                   v_cta_for_credito, v_nom_cta_credito
              from ge_cuentas a
             where a.nro_cuenta = v_nro_cta_credito; -- contiene el nro de cuenta
             -- credito
             if v_cod_mon_credito <> v_cod_mon_debito  then
                if nvl(p_modo,'x') <> 'A' then
                    Begin
                    lp_con_mon_a_moneda(v_cod_mon_debito,
                                        v_cod_mon_credito,
                                        v_monto,
                                        v_mto_credito,
                                        v_cot_debito,
                                        v_cot_credito);
                    Exception
                       When OTHERS then
                            v_cod_respuesta := paw_bce.v_cod_otr_error;
                    End;
                end if;
                if v_cod_mon_debito <> v_cod_mon_local then
                   v_cotizacion := v_cot_debito;
                else
                   v_cotizacion := v_cot_credito;
                end if;
             else
                v_mto_credito := v_monto;
             end if;
             if v_mto_credito <= 0 then
                v_cod_respuesta := paw_bce.v_cod_mto_invalido;
             elsif v_cod_mad_credito not in (31,41) then
                v_cod_respuesta := paw_bce.v_cod_cta_invalida;
             elsif v_est_cta_credito not in ('A','I','N','S') then
                v_cod_respuesta := paw_bce.v_cod_cta_invalida;
             elsif pag_cta.fu_ver_tra_prohibida(v_nro_cta_credito,v_cod_tra_padre, 9, 91) = 'S' then
                v_cod_respuesta := paw_bce.v_cod_tra_prohibida;
             --elsif v_cod_mad_credito = 31 and pag_cta.fu_obt_cta_cte_comb(v_nro_cta_credito) is not null then
             --   v_cod_respuesta := paw_bce.v_cod_cta_invalida;
             -- RAMG: se anulo a pedido de L.Kublik el 05/04/2010
             else
                pag_cta.pr_ver_operacion(v_nro_cta_credito,v_cod_tra_padre,9,91,'C',v_cod_mon_credito, v_mto_credito, v_cod_ofi_origen,
                                         v_cod_mod_credito, v_cod_mad_credito, v_nvo_est_credito, v_sal_dis_credito,
                                         v_procesa,602);
                if v_procesa = 'N' then
                   -- no se puede debitar
                   v_cod_respuesta := paw_bce.v_cod_cta_invalida;
                elsif v_nro_doc_credito is not null and lf_cta_valida(v_nro_cta_credito, v_nro_doc_credito)='N' then
                   -- no se puede acreditar a la cuenta de este nro de documento
                   if v_cod_respuesta = paw_bce.v_cod_aprobado then
                      v_cod_respuesta := paw_bce.v_cod_cta_invalida;
                   end if;
                end if;
             end if;
             -- valido la duplicación de pendientes
             if v_cod_respuesta = paw_bce.v_cod_aprobado then
               if fu_ver_mov_pendiente(v_cod_per_empresa, v_nro_cta_debito, 
                                           v_nro_cta_credito, v_monto, '030') = 'S' then
                 v_cod_respuesta := paw_bce.v_cod_pag_pendiente;
               end if;
             end if;
             -- valida la duplicación de transferencias    
             if v_cod_respuesta = paw_bce.v_cod_aprobado then
               if fu_ver_transaccion(503, v_cod_tra_padre, v_nro_cta_debito, v_monto) = 'S' then                    
                 v_cod_respuesta := v_cod_mov_ya_ingresado;
               end if;
             end if;
        exception
            when no_data_found then
               v_cod_respuesta  := paw_bce.v_cod_cta_invalida;
            when too_many_rows then
               v_cod_respuesta  := paw_bce.v_cod_cta_duplicada;
            when others then
               v_cod_respuesta  := paw_bce.v_cod_cta_invalida;
        end;
        
        -- CR: modificado para control de límite de operaciones
        -- si viene de autorizar, no hace falta controlar
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
           if v_modo in ('C', 'V', 'A') and nvl(p_modo,'x') <> 'A' then
              v_res_limite := fu_obt_limite('030', 
                                            nvl(v_cod_per_empresa,v_cod_persona), 
                                            v_nro_cta_debito, 
                                            v_cod_mon_debito, 
                                            503, 
                                            v_cod_tra_padre,
                                            v_monto,
                                            v_modo);
           end if;
        end if;
        
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
           if nvl(p_modo, 'x') <> 'A' and v_modo in ('C','A') then 
              if v_res_limite IN ('10', '11') then -- clave transaccional requerida
                 v_cod_respuesta := lf_obt_cla_validar(p_parametros,v_cod_persona,v_cod_per_empresa,168,'T');
              end if;
                
              if v_cod_respuesta = paw_bce.v_cod_aprobado then
                 if v_res_limite IN ('01', '11') then -- token requerido
                    v_cod_respuesta := fu_obt_tok_validar(p_parametros,v_cod_persona,v_cod_per_empresa,200, v_modo);
                 end if;
              end if;  
           end if;
        end if;
        --

        if v_cod_respuesta = paw_bce.v_cod_aprobado then
           -- no hay problemas hasta aquí
           if v_modo = 'V' then -- validación
              return lpad(ltrim(lf_for_money(v_cotizacion,16)),16,'0')||
                     lf_for_char(v_cta_for_debito,17)||
                     lf_for_char(v_nom_cta_debito,50)||
                     lf_for_char(rpad(v_cod_mon_debito,3,'.'),3)||
                     lf_for_money(v_monto,16)||
                     lf_for_char(v_cta_for_credito,17)||
                     lf_for_char(v_nom_cta_credito,50)||
                     lf_for_char(rpad(v_cod_mon_credito,3,'.'),3)||
                     lf_for_money(v_mto_credito,16)||
                     -- para límite de operaciones
                     lf_for_char(v_res_limite,2);
           elsif v_modo = 'C' then -- grabación en pendiente
              if v_cod_mon_debito <> v_cod_mon_local and
                 v_cod_mon_debito <> v_cod_mon_credito and
                 v_cod_mon_credito = v_cod_mon_local then
                 v_mto_equ_local := v_mto_credito;
              else
                 v_mto_equ_local  := null;
              end if;
              --- inserto el movimiento pendiente de autorización
              select s_nro_documento.nextval into v_nro_documento from dual;
              insert into bw_mov_pendientes
                (nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda,
                 descripcion, monto, cotizacion, mto_equ_local, nro_cta_contra,
                 estado,can_aut_requeridas, can_aut_faltantes, cod_per_ingreso, mto_contra, cot_contra,
                 etiqueta, dato, etiqueta2, dato2)
              values
                 (v_nro_documento,nvl(v_cod_per_empresa,v_cod_persona),sysdate,'030',v_nro_cta_debito,v_cod_mon_debito,
                  'Transferencia entre Cuentas',v_monto, v_cot_debito, v_mto_equ_local, v_nro_cta_credito,
                  'P', v_can_aut_requeridas, v_can_aut_requeridas, v_cod_persona, v_mto_credito, v_cot_credito,
                  'Nro.Identificacion',v_nro_doc_credito, 'Concepto',substr(v_concepto,0,50)
                 );
              -- registro del movimiento
              lp_reg_operacion(v_nro_cta_debito /*p_nro_cuenta*/,
                               v_cod_mon_debito /*p_cod_moneda */,
                               v_monto /*p_monto*/,
                               v_nro_cta_credito /*p_nro_cta_contra*/
                               );
              return lf_for_number(v_can_aut_requeridas,3)||lf_for_number(v_nro_documento,15);
           elsif v_modo = 'A' then -- confirmación de operación
              -- seteo las variables
              v_nro_secuencia := 0;
              pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                                        v_fec_valor,
                                        v_cod_tra_padre, 'N', 'N',
                                        v_nro_secuencia,
                                        null, v_cod_ofi_origen, 9, 91);
              -- esta la cuenta en condiciones, verifico el horario
              lp_ver_horario;
              -- actualizo la cuenta de débito
        -- 10/05/2011 Ajustes segun AP-1617 Soporte IT
              v_mto_equ_local := null;
              if v_cod_mon_debito <> v_cod_mon_local   and
                 v_cod_mon_debito <> v_cod_mon_credito then

                 v_cotizacion    := v_cot_debito;
                 if v_cod_mon_debito = v_cod_mon_local then
                    v_mto_equ_local := v_monto;
                 else
                    v_mto_equ_local := round(v_cot_debito * v_monto,0);   
                 end if;
              else
                 v_cotizacion     := null;
                 v_mto_equ_local  := null;
              end if;
              pag_cta.PR_ACT_OPERACION(v_nro_cta_debito, v_hor_actual,'D',
                                       v_cod_mon_debito, v_monto,
                                       v_cod_tra_padre, 503, v_nro_operacion,
                                       v_cotizacion, v_cod_ofi_origen, 9, 91,
                                       null, null, nvl(v_concepto,'Transf. a '||v_nro_cta_credito),
                                       'N', v_nro_secuencia, v_fec_valor,
                                       null, null, v_mto_equ_local);
             if nvl(pag_cta.g_cod_error,0)= 0 then
                if v_cod_mon_credito <> v_cod_mon_local  and
                   v_cod_mon_debito <> v_cod_mon_credito then

                   v_cotizacion    := v_cot_credito;
                   if v_cod_mon_debito = v_cod_mon_local then
                      v_mto_equ_local := v_monto;
                   end if;
                else
                   v_cotizacion     := null;
                   v_mto_equ_local  := null;
                end if;
                pag_cta.PR_ACT_OPERACION(v_nro_cta_credito, v_hor_actual,'C',
                                         v_cod_mon_credito, v_mto_credito,
                                         v_cod_tra_padre, 602, v_nro_operacion,
                                         v_cot_credito, v_cod_ofi_origen, 9, 91,
                                         null, null, nvl(v_concepto,'Transf. de '||v_nro_cta_debito),
                                         'N', v_nro_secuencia, v_fec_valor,
                                         null, null, v_mto_equ_local);
                if nvl(pag_cta.g_cod_error,0)<> 0 then
                   -- hubo error en el crédito
                  --raise_application_error(-20006,'Credito '||v_nro_Cta_credito||'-'||pag_cta.G_MSJ_ERROR);
                  v_cod_respuesta := paw_bce.v_cod_tra_invalida;
                end if;
                /*Notificar evento*/
              -- Notificacion al debito
              BEGIN
                 v_res_notificacion:=PAW_NOT.fu_not_transferencias(v_nro_cta_debito, v_monto, v_cod_mon_debito, 'D', v_fec_valor);
              EXCEPTION
                 WHEN OTHERS THEN
                    NULL;
              END;
              --Notificacion al credito
              BEGIN
                 v_res_notificacion:=PAW_NOT.fu_not_transferencias(v_nro_cta_credito, v_mto_credito, v_cod_mon_credito, 'C', v_fec_valor);
              EXCEPTION
                 WHEN OTHERS THEN
                    NULL;
              END;                
             else
                -- hubo error en el débito
                --raise_application_error(-20006,'Debito '||v_nro_Cta_debito||'-'||pag_cta.G_MSJ_ERROR);
                v_cod_respuesta := paw_bce.v_cod_tra_invalida;
             end if ;
           end if;
        end if;
     end if;
  end if;
  -- registro del movimiento
  lp_reg_operacion(v_nro_cta_debito /*p_nro_cuenta*/,
                   v_cod_mon_debito /*p_cod_moneda */,
                   v_monto /*p_monto*/,
                   v_nro_cta_credito /*p_nro_cta_contra*/
                   );
  -- no se responde nada, solo se debe setear el v_cod_respuesta
  return null;
end;
-- fin de 030-confirmación de transferencia entre cuentas

-- 031 - pago de prestamos
function fu_pro_operacion_031(p_parametros in varchar2,
                              p_nro_cta_debito  in varchar2 default null,
                              p_monto           in number   default null,
                              p_nro_prestamo    in varchar2 default null,
                              p_modo            in varchar2 default null,
                              p_can_cuo_pagada  in number   default null)
  return clob is
-- datos recibidos
v_nro_prestamo    varchar2(16); -- nro de tarjeta a pagar
v_modo            varchar2(3);   -- modo S/V/C
-- datos a responder
v_detalles        varchar2(3000) := null;   -- datos de las cuentas
-- variables
v_nro_cuenta      varchar2(17);
v_cta_formateada  varchar2(17);
v_nom_titular     varchar2(100);
v_tip_prestamo    varchar2(35);
v_cod_moneda      varchar2(3);
--
v_cod_mod_cta     number(4);
v_cod_mad_cta     number(4);
v_cod_ofi_cta     number(4);
v_cod_retencion   number(4);     -- codigo de retencion
v_fec_fin_retencion date;        -- fecha final de la retencion
--
v_cod_tra_padre   number(4) := 360;
v_cod_transaccion number(4);
v_nro_cta_debito  varchar2(17);
v_cod_mon_debito  varchar2(4);
v_nro_sobre       number(10);
v_imp_efectivo    number(18,2) := 0;   -- efectivo
v_imp_che_n_bco   number(18,2) := 0;  -- che.ntro.bco
v_imp_che_o_bco   number(18,2) := 0; -- che otros bcos.
v_imp_debito      number(18,2) := 0;   -- debito
v_tot_pago        number(18,2) := 0;   -- total
v_can_cuo_pagada  number(5)    := 0;
-- cuotas
v_det_cuotas      varchar2(7000); -- detalle de las cuotas
v_can_cuotas      number(5) := 0;
v_cantidad        number(5) := 0;
v_nro_cuota_desde number(5) := null;
v_nro_cuota_hasta number(5) := null;
-- variables
v_mto_cobrado        number(18,2);      -- Mto cobrado (no se despliega)
v_tot_capital        number(18,2);      -- Capital (no se despliega )
v_tot_interes        number(18,2);      -- Interes (no se despliega )
v_tot_cap_int        number(18,2);      -- Capital + interes + int.adel (DESPLIEGA : importe )
v_tot_int_adelantado number(18,2);      -- Interes adelantado (no despliega)
v_tot_mora           number(18,2);      -- Mora s/capital (no despliega)
v_tot_mora_interes   number(18,2);      -- Mora s/Interes (DESPLIEGA : Mora s/interes )
v_tot_mora_int_adel  number(18,2);      -- Mora interes adelantado (no desp)
v_tot_impuesto       number(18,2);      -- Total impuesto (DESPLIEGA : ley 125/91)
v_tot_cargo          number(18,2);      -- Total cargo (DESPLIEGA : Cargo + IVA )
v_tot_cargo_iva      number(18,2);      -- Total cargo IVA  (no desp)
v_tot_int_descontado number(18,2);      -- Total interes descontado (no desp)
v_tot_a_cobrar       number(18,2);      -- Total a cobrar (DESPLIEGA: cap+int+morai+morac+imp+cargo)
v_tot_mora_cap       number(18,2);      -- Total mora s/capital (DESPLIEGA: v_tot_mora+v_tot_mora_int_adel)
v_tot_punitorio      number(18,2);      -- Total monto punitorio (DESPLIEGA : Punitorio)
v_cod_error          varchar2(03) := '000'; -- sin errores
v_msj_error          varchar2(100) := 'OK'; -- sin errores
v_dia_mora           number(10);
--
v_cta_for_debito  varchar2(17);  -- cuenta formateada
v_est_cta_debito  varchar2(1);   -- estado de la cuenta
v_cod_mod_debito  number(4);     -- modulo de la cuenta
v_cod_mad_debito  number(4);     -- modalidad de la cuenta
v_cod_ofi_debito  number(4);     -- oficina de la cuenta
v_nvo_est_debito  varchar2(1) := null; -- cambio de estado de cuenta
v_cot_debito      number(18,2) := null;
v_nom_cta_debito  varchar2(100);
v_cotizacion      number(18,4) := null;
v_nro_documento   number(15);
-- limite operativo
v_res_limite      varchar2(2);
--
cursor cuotas(p_nro_cuenta in varchar2) is
  select  a.nro_cuota,
          -- nvl(sal_capital,0) + nvl(sal_interes,0) + nvl(sal_int_documentado,0) mto_cuota,
          nvl(c.mto_capital,0) + nvl(c.mto_interes,0) + nvl(c.mto_int_documentado, 0) +
          nvl(c.mto_int_moratorio, 0) + nvl(c.mto_int_mor_interes, 0) + nvl(c.mto_int_mor_adelantado, 0) +
          nvl(c.mto_int_punitorio, 0) + nvl(c.mto_cargo, 0) + nvl(c.mto_impuesto, 0) mto_cuota,
          a.fec_vencimiento, a.fec_ult_pago,
          /*decode(sign(v_fec_actual - a.fec_vencimiento),1,
                 (v_fec_actual - a.fec_vencimiento), 0 ) se dejo en 0 a pedido de BBVA */ 0 dia_mora
    from pr_cobros_tmp c, pr_cuotas a
   where c.nro_cuenta = a.nro_cuenta
     and c.nro_cuota  = a.nro_cuota
     ---
     and a.nro_cuenta = p_nro_cuenta
     and a.nro_cuota > 0
     and a.estado <> 'N'
     and a.fec_vencimiento <= sysdate + 25
   order by a.nro_cuota;
begin
  -- 0. Para operaciones de prestamo se graba el usuario con el que se conecta
  v_cod_usuario := user;
  if nvl(p_modo,'x') = 'A' then
     v_nro_prestamo := p_nro_prestamo;
     v_nro_cta_debito := p_nro_cta_debito;
     v_imp_debito     := p_monto;
     v_can_cuo_pagada := p_can_cuo_pagada;
     v_modo           := p_modo;
  else
     v_nro_prestamo   := lf_obt_cta_limpia(substr(p_parametros,66,16)); -- nro de tarjeta a pagar
     v_modo           := substr(p_parametros,82,1);
     -- 1. valido la clave del cliente
     pr_val_clave(p_parametros);
     if v_modo = 'C' and v_can_aut_requeridas = 0 then
        -- se confirma directamente la operacion, porque no requiere autorizacion
        v_modo := 'A'; -- CONFIRMACION
     end if;
  end if;
  --Verifica los permisos  
  if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(p_modo,'x') <> 'A' then
     v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '031');
     if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
        v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
     end if;
  end if;        
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     begin
       select a.nro_cuenta,
              fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina,a.nro_cuenta, a.cod_moneda) cta_formateada,
              fue_obt_nom_persona(b.cod_persona) nom_titular,
              fug_obt_des_modal(a.cod_modulo,a.cod_modalidad) tip_prestamo,
              a.cod_moneda,
              a.cod_modulo,
              a.cod_modalidad,
              a.cod_oficina
        into v_nro_cuenta,
             v_cta_formateada,
             v_nom_titular,
             v_tip_prestamo,
             v_cod_moneda,
             v_cod_mod_cta,
             v_cod_mad_cta,
             v_cod_ofi_cta
        from ge_cta_clientes b, pr_cta_prestamos a
       where a.nro_cuenta = v_nro_prestamo
         and a.nro_cuenta = b.nro_cuenta
         and b.cod_modalidad not in (62, 608)
         and b.relacion = 'P';

     exception
        when no_data_found then
           v_cod_respuesta := paw_bce.v_cod_cta_invalida;
     end;

  end if;
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     if v_modo = 'S' then -- seleccion de datos
       -- esta la cuenta en condiciones, verifico el horario del deposito
       -- cuotas del prestamo
       lp_ver_horario;
       v_can_cuotas := 0;
       v_det_cuotas := null;
           ---- Desde aca
       v_nro_cuota_desde := 0;
       v_nro_cuota_hasta := 999;
       pap_pre.PR_INI_AUTORIZACION;
       pap_pre.PR_OBT_DEU_PRESTAMO(v_nro_cuenta,
                 v_fec_actual,
                 v_nro_cuota_desde,
                 v_nro_cuota_hasta,
                 v_cod_ofi_origen,
                 v_mto_cobrado,
                 v_cod_error,
                 v_msj_error,
                 v_tot_capital,
                 v_tot_interes,
                 v_tot_int_adelantado,
                 v_tot_mora,
                 v_tot_mora_interes,
                 v_tot_mora_int_adel,
                 v_tot_punitorio,
                 v_tot_impuesto,
                 v_tot_cargo,
                 v_tot_cargo_iva,
                 v_tot_int_descontado,
                 v_dia_mora,
                 v_cod_tra_padre,  --- cod_tra_padre
                 'N'); --- cancela

       for cu in cuotas(v_nro_cuenta) loop
           v_can_cuotas := v_can_cuotas + 1;
        if v_cod_error <> 0 then
           v_cod_respuesta := paw_bce.v_cod_cta_invalida;
        else
            -- sumo los totales
           v_det_cuotas := v_det_cuotas ||
                           lf_for_number(cu.nro_cuota,5)||
                           lf_for_money(cu.mto_cuota,16)||
                           lf_for_date(cu.fec_vencimiento);
        end if;
       end loop;
       -- busco las cuentas de debito
       if v_cod_respuesta = paw_bce.v_cod_aprobado then
          v_detalles := fu_pro_operacion_011(p_parametros, 'D',v_cod_moneda,'031');
       end if;
        -- Finalmente verifico si no tiene cobros pendientes de ser aplicados...
        Declare
          v_can_pag_pend number(5) := 0;
        Begin
          Select count(*) into v_can_pag_pend
            from pr_cobros_noc
           where nro_cuenta = v_nro_cuenta
             and estado = 'I';
          If v_can_pag_pend > 0 then
             v_cod_respuesta := paw_bce.v_cod_pag_pendiente;
          End if;
        End;
        --
       return lf_for_char(v_cta_formateada,17)||
              lf_for_char(v_nom_titular,50)||
              lf_for_char(v_tip_prestamo,35)||
              lf_for_char(rpad(v_cod_moneda,3,'.'),3)||
              lf_for_number(v_can_cuotas,3)||
              lf_for_char(substr(v_detalles,1,3),3)||
              v_det_cuotas||
              substr(v_detalles,4);
     elsif v_modo = 'V' then -- validacion
        -- esta la cuenta en condiciones, verifico el horario del deposito
        lp_ver_horario;
        --
        v_can_cuo_pagada := substr(p_parametros,83,3);
        v_nro_cta_debito := trim(substr(p_parametros,86,17));
        if v_nro_cta_debito is not null then
          if (instr(v_nro_cta_debito,'-') > 0 or instr(v_nro_cta_debito,' ') > 0) then
             -- se extrae los guiones de la cuenta
              v_nro_cta_debito := to_number(substr(v_nro_cta_debito,7));
          end if;
        end if;
        v_nro_cuota_desde := null;
        v_nro_cuota_hasta := null;
        v_cantidad := 0;
        for cu in cuotas(v_nro_cuenta) loop
            if v_nro_cuota_desde is null then
               v_nro_cuota_desde := cu.nro_cuota;
            end if;
            v_cantidad := v_cantidad + 1;
            if v_cantidad >= v_can_cuo_pagada then
               v_nro_cuota_hasta := cu.nro_cuota;
               exit;
            end if;
        end loop;
        -- valido la duplicacion de pago de préstamos
         declare
             v_cant_cob number(5);
         begin
          select count(*)
            into v_cant_cob
            from pr_cobros
           where nro_cuenta = v_nro_cuenta
             and usu_insercion = v_cod_usuario
             and fecha = v_fec_actual
             and ((sysdate) -fec_insercion)*1440 <= v_min_transaccion; -- para poder pagar mas de una cuota en el día

          If v_cant_cob > 0 Then
             v_cod_respuesta := paw_bce.v_cod_mov_ya_ingresado;
          end if;
          select count(*)
            into v_cant_cob
            from bw_mov_pendientes
           where nro_cta_contra = v_nro_cuenta
             and usu_insercion = v_cod_usuario
             and cod_tip_mensaje = '031'
             and estado = 'P';
          If v_cant_cob > 0 Then
             v_cod_respuesta := paw_bce.v_cod_mov_ya_ingresado;
          end if;
         exception
            when no_data_found then
               null;
            when too_many_rows then
               v_cod_respuesta := paw_bce.v_cod_mov_ya_ingresado;
         end;

        -- obtengo los datos del prestamos
        pap_pre.PR_INI_AUTORIZACION;
        pap_pre.PR_OBT_DEU_PRESTAMO(v_nro_cuenta,
                     v_fec_actual,
                     v_nro_cuota_desde,
                     v_nro_cuota_hasta,
                     v_cod_ofi_origen,
                     v_mto_cobrado,
                     v_cod_error,
                     v_msj_error,
                     v_tot_capital,
                     v_tot_interes,
                     v_tot_int_adelantado,
                     v_tot_mora,
                     v_tot_mora_interes,
                     v_tot_mora_int_adel,
                     v_tot_punitorio,
                     v_tot_impuesto,
                     v_tot_cargo,
                     v_tot_cargo_iva,
                     v_tot_int_descontado,
                     v_dia_mora,
                     v_cod_tra_padre,  --- cod_tra_padre
                     'N'); --- cancela
        if v_cod_error <> 0 then
           v_cod_respuesta := paw_bce.v_cod_cta_invalida;
        else
            -- sumo los totales
            v_tot_cap_int  := nvl(v_tot_capital,0) + nvl(v_tot_interes,0)+ nvl(v_tot_int_adelantado,0);
            v_tot_mora_cap := nvl(v_tot_mora,0) + nvl(v_tot_mora_int_adel,0);

            v_tot_a_cobrar:= nvl(v_tot_cap_int,0) +
                           nvl(v_tot_mora_interes,0) +
                           nvl(v_tot_mora_cap,0) +
                           nvl(v_tot_punitorio,0) +
                           nvl(v_tot_impuesto,0) +
                           nvl(v_tot_cargo,0) ;
            -- valido la cuenta de debito
            pr_val_cta_debito( v_nro_cta_debito,
                               v_cod_tra_padre,
                               nvl(v_tot_a_cobrar,0),
                               v_cod_mon_debito,
                               v_cod_mod_debito,
                               v_cod_mad_debito,
                               v_cod_ofi_debito,
                               v_cta_for_debito,
                               v_nom_cta_debito);
            if v_cod_moneda <> v_cod_mon_debito and v_cod_respuesta = paw_bce.v_cod_aprobado then
              -- moneda diferentes
              v_cod_respuesta := paw_bce.v_cod_tra_invalida;
            end if;
        end if;
        -- limite por operacion 
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
           v_res_limite := fu_obt_limite('031', 
                              nvl(v_cod_per_empresa,v_cod_persona), 
                              v_nro_cta_debito, 
                              v_cod_mon_debito, 
                              503, 
                              v_cod_tra_padre, 
                              v_tot_a_cobrar,
                              v_modo );
        end if;
        --
        if v_cod_respuesta <> paw_bce.v_cod_aprobado then
            return null;
        else
            return  lpad(ltrim(lf_for_money(v_cotizacion,16)),16,'0')||
                   lf_for_char(v_cta_for_debito,17)||
                   lf_for_char(v_nom_cta_debito,50)||
                   lf_for_char(rpad(v_cod_mon_debito,3,'.'),3)||
                   lf_for_money(v_tot_a_cobrar,16)||
                   lf_for_char(v_cta_formateada,17)||
                   lf_for_char(v_nom_titular,50)||
                   lf_for_char(rpad(v_cod_moneda,3,'.'),3)||
                   lf_for_money(v_tot_cap_int,16)||
                   lf_for_money(nvl(v_tot_mora_cap,0)+nvl(v_tot_mora_interes,0),16)||
                   lf_for_money(nvl(v_tot_cargo,0)+nvl(v_tot_punitorio,0),16)||
                   lf_for_money(v_tot_impuesto,16)||
                   lf_for_money(v_tot_a_cobrar,16)||
                   -- parametro nuevo por limite
                   lf_for_char(v_res_limite, 2);
        end if;

     elsif v_modo in ('A','C') then  -- confirmacion de operacion
        -- esta la cuenta en condiciones, verifico el horario del deposito
        lp_ver_horario;
        -- verifico la validez de los montos
        begin
          if nvl(p_modo,'x') = 'A' then -- ya vienen los datos como parametros
            v_can_cuo_pagada := p_can_cuo_pagada;
            v_nro_cta_debito := p_nro_cta_debito;
          else
            v_can_cuo_pagada := substr(p_parametros,83,3);
            v_nro_cta_debito := trim(substr(p_parametros,86,17));
            if v_nro_cta_debito is not null then
              if (instr(v_nro_cta_debito,'-') > 0 or instr(v_nro_cta_debito,' ') > 0) then
                 -- se extrae los guiones de la cuenta
                  v_nro_cta_debito := to_number(substr(v_nro_cta_debito,7));
              end if;
            end if;
          end if;

          v_nro_cuota_desde := null;
          v_nro_cuota_hasta := null;
          v_cantidad := 0;
          for cu in cuotas(v_nro_cuenta) loop
              if v_nro_cuota_desde is null then
                 v_nro_cuota_desde := cu.nro_cuota;
              end if;
              v_cantidad := v_cantidad + 1;
              if v_cantidad >= v_can_cuo_pagada then
                 v_nro_cuota_hasta := cu.nro_cuota;
                 exit;
              end if;
          end loop;

          if nvl(p_modo,'x') = 'A' then -- ya vienen los datos como parametros
              v_nro_sobre     := 0;
              v_imp_efectivo  := 0;
              v_imp_che_n_bco := 0;
              v_imp_che_o_bco := 0;
              v_imp_debito    := p_monto;
              v_tot_pago      := p_monto;
          else
              v_nro_sobre      := trim(substr(p_parametros,103,10));
              v_imp_efectivo   := nvl(to_number(replace(trim(substr(p_parametros,113,18)),',','.')),0);   -- efectivo
              v_imp_che_n_bco  := nvl(to_number(replace(trim(substr(p_parametros,131,18)),',','.')),0);  -- che.ntro.bco
              v_imp_che_o_bco  := nvl(to_number(replace(trim(substr(p_parametros,149,18)),',','.')),0);  -- che otros bcos.
              v_imp_debito     := nvl(to_number(replace(trim(substr(p_parametros,167,18)),',','.')),0);   -- total
              v_tot_pago       := nvl(to_number(replace(trim(substr(p_parametros,185,18)),',','.')),0);   -- total
          end if;
          if v_cod_moneda = v_cod_mon_local then
             if v_imp_efectivo <> trunc(v_imp_efectivo) or
                v_imp_che_n_bco <> trunc(v_imp_che_n_bco) or
                v_imp_che_o_bco <> trunc(v_imp_che_o_bco)  or
                v_imp_debito <> trunc(v_imp_debito) then
               -- monto con decimales y en guaranies no permite
               v_cod_respuesta := paw_bce.v_cod_mto_invalido;
             elsif nvl(v_imp_efectivo,0) + nvl(v_imp_che_n_bco,0) +
                   nvl(v_imp_che_o_bco,0) + nvl(v_imp_debito,0) <> nvl(v_tot_pago,0) then
                   -- total depositado invalido
                   v_cod_respuesta := paw_bce.v_cod_tot_invalido;
             end if;
          end if;
          if v_nro_cta_debito is not null then
              -- valido la cuenta de debito
              pr_val_cta_debito( v_nro_cta_debito,
                                 v_cod_tra_padre,
                                 nvl(v_tot_pago,0),
                                 v_cod_mon_debito,
                                 v_cod_mod_debito,
                                 v_cod_mad_debito,
                                 v_cod_ofi_debito,
                                 v_cta_for_debito,
                                 v_nom_cta_debito);
              if v_modo = 'C' and v_can_aut_requeridas = 0 then
                 -- se confirma directamente la operacion, porque no requiere autorizacion
                 v_modo := 'A'; -- CONFIRMACION
              end if;
          end if;
        exception
          when others then
             -- monto invalido
             v_cod_respuesta := paw_bce.v_cod_mto_invalido;
             --raise_application_error(-20000,sqlerrm);
        end;
        if v_cod_respuesta = paw_bce.v_cod_aprobado and v_nro_cta_debito is not null then
           if lf_val_cta_origen(v_nro_cta_debito,nvl(v_cod_per_empresa,v_cod_persona)) = 'N' then
              -- no es una cuenta del cliente
              v_cod_respuesta := paw_bce.v_cod_cta_invalida;
           end if;
        end if;
        
        -- para limite operativo
        if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(p_modo,'x') <> 'A' then
           v_res_limite := fu_obt_limite('031', 
                            nvl(v_cod_per_empresa,v_cod_persona), 
                            v_nro_cta_debito, 
                            v_cod_mon_debito, 
                            503, 
                            v_cod_tra_padre, 
                            v_tot_pago,
                            v_modo );
        end if;
          
        if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(p_modo,'x') <> 'A'  then            
           if v_res_limite IN ('10', '11') then -- clave transaccional requerida
              v_cod_respuesta := lf_obt_cla_validar(p_parametros,v_cod_persona,v_cod_per_empresa,205,'T');
           end if;
                
           if v_cod_respuesta = paw_bce.v_cod_aprobado then
              if v_res_limite IN ('01', '11') then -- token requerido
                 v_cod_respuesta := fu_obt_tok_validar(p_parametros,v_cod_persona,v_cod_per_empresa,237, v_modo);
              end if;
           end if;
        end if;
        -- fin limite
        
        if v_cod_respuesta = paw_bce.v_cod_aprobado and v_modo = 'C' then
           -- grabacion en pendiente
           -- registro del movimiento
           lp_reg_operacion(v_nro_prestamo /*p_nro_cuenta*/,
                            v_cod_moneda /*p_cod_moneda */,
                            v_tot_pago /*p_monto*/,
                            v_nro_cta_debito /*p_nro_cta_contra*/,
                            v_cantidad,
                            'Efectivo',
                            v_imp_efectivo,
                            'Cheques',
                            v_imp_che_n_bco + v_imp_che_o_bco
                            );
            if v_imp_debito > 0 then
              --- inserto el movimiento pendiente de autorizacion
              select s_nro_documento.nextval into v_nro_documento from dual;
              insert into bw_mov_pendientes
                (nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda,
                 descripcion, monto, nro_cta_contra,etiqueta, dato,
                 estado,can_aut_requeridas, can_aut_faltantes, cod_per_ingreso, mto_contra)
              values
                 (v_nro_documento,nvl(v_cod_per_empresa,v_cod_persona),sysdate,'031',v_nro_cta_debito,v_cod_moneda,
                  'Pago de Prestamos',v_imp_debito, v_nro_prestamo,'Cant.de Cuotas',v_can_cuo_pagada,
                  'P', v_can_aut_requeridas, v_can_aut_requeridas, v_cod_persona, v_imp_debito
                 );
              return lf_for_number(v_can_aut_requeridas,3)||lf_for_number(v_nro_documento,15);
            else
               v_cod_respuesta := paw_bce.v_cod_mto_invalido;
            end if;
        elsif v_cod_respuesta = paw_bce.v_cod_aprobado and v_modo = 'A' then
           -- registro del movimiento
           lp_reg_operacion(v_nro_prestamo /*p_nro_cuenta*/,
                            v_cod_moneda /*p_cod_moneda */,
                            v_tot_pago /*p_monto*/,
                            v_nro_cta_debito /*p_nro_cta_contra*/,
                            v_cantidad,
                            'Efectivo',
                            v_imp_efectivo,
                            'Cheques',
                            v_imp_che_n_bco + v_imp_che_o_bco
                            );
          -- sigue sin problemas hasta aqui, ya puedo grabar
          if v_imp_efectivo > 0 then
             -- importe en efectivo
              v_cod_transaccion := 613;
              -- obtengo el codigo y fin de retencion
              pag_cta.pr_obt_retencion(v_fec_actual,
                                       v_nro_cuenta,
                                       v_cod_mod_cta,
                                       v_cod_mad_cta,
                                       v_cod_transaccion,
                                       v_cod_moneda,
                                       v_cod_retencion,
                                       v_fec_fin_retencion);
              -- genero el movimiento respectivo
              lp_ins_movimiento( v_cod_mod_cta,
                                 v_cod_mad_cta,
                                 v_cod_ofi_cta,
                                 v_nro_cuenta,
                                 v_cod_moneda,
                                 v_cod_tra_padre,
                                 v_cod_transaccion,
                                 v_nro_sobre,
                                 v_imp_efectivo,
                                 'E', -- EFECTIVO
                                 v_es_mov_noc,
                                 v_cod_retencion,
                                 v_fec_fin_retencion);
          end if;
          if v_imp_che_n_bco > 0 then
             -- importe en cheques ntro banco
              v_cod_transaccion := 614;
              -- obtengo el codigo y fin de retencion
              pag_cta.pr_obt_retencion(v_fec_actual,
                                       v_nro_cuenta,
                                       v_cod_mod_cta,
                                       v_cod_mad_cta,
                                       v_cod_transaccion,
                                       v_cod_moneda,
                                       v_cod_retencion,
                                       v_fec_fin_retencion);
              -- genero el movimiento respectivo
              lp_ins_movimiento( v_cod_mod_cta,
                                 v_cod_mad_cta,
                                 v_cod_ofi_cta,
                                 v_nro_cuenta,
                                 v_cod_moneda,
                                 v_cod_tra_padre,
                                 v_cod_transaccion,
                                 v_nro_sobre,
                                 v_imp_che_n_bco,
                                 'C', -- cheque ntro bco
                                 v_es_mov_noc,
                                 v_cod_retencion,
                                 v_fec_fin_retencion);
          end if;
          if v_imp_che_o_bco > 0 then
             -- importe en cheques otros bancos
             v_imp_alt_valor := fug_obt_pardinamico('MTO_CHE_RET_CERO',null,null,v_cod_moneda,null,null );
             IF v_cod_moneda = v_cod_mon_local THEN 
                /*if v_imp_che_o_bco >= v_imp_alt_valor then
                  if v_horario = 'D' and v_hor_actual > v_hor_cie_cheques then
                      -- se graba ya como cheques 48 hs de retencion
                     v_cod_transaccion := 632;
                     v_tip_monto       := 'S';
                  else
                     v_cod_transaccion := 607;                
                     v_tip_monto       := 'O';
                  end if;
               else*/              
                 if v_horario = 'D' and v_hor_actual > v_hor_cie_cheques then
                   -- se graba ya como cheques 48 hs de retencion
                   v_cod_transaccion := 632;
                   v_tip_monto       := 'S';
                 else
                   v_cod_transaccion := 615;
                   v_tip_monto       := 'T';
                 end if;
               --end if;
             ELSE
                v_cod_transaccion := 615;
                v_tip_monto       := 'T';  
                IF v_horario = 'D' and v_hor_actual > v_hor_cie_cheques THEN
                   -- se graba ya como cheques 48 hs de retencion
                   v_cod_transaccion := 632;
                   v_tip_monto       := 'S';
                END IF;
             END IF;         
              -- obtengo el codigo y fin de retencion
              pag_cta.pr_obt_retencion(v_fec_actual,
                                       v_nro_cuenta,
                                       v_cod_mod_cta,
                                       v_cod_mad_cta,
                                       v_cod_transaccion,
                                       v_cod_moneda,
                                       v_cod_retencion,
                                       v_fec_fin_retencion);
              -- genero el movimiento respectivo
              lp_ins_movimiento( v_cod_mod_cta,
                                 v_cod_mad_cta,
                                 v_cod_ofi_cta,
                                 v_nro_cuenta,
                                 v_cod_moneda,
                                 v_cod_tra_padre,
                                 v_cod_transaccion,
                                 v_nro_sobre,
                                 v_imp_che_o_bco,
                                 v_tip_monto, -- cheque otros bcos
                                 v_es_mov_noc,
                                 v_cod_retencion,
                                 v_fec_fin_retencion);
          end if;

          -- actualizo el control de caja
          update cj_controles
             set tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_imp_che_n_bco,0),
                 sal_actual = nvl(sal_actual,0) + nvl(v_imp_efectivo,0),
                 tot_debitos = nvl(tot_debitos,0) + nvl(v_imp_efectivo,0),
                 can_debitos = nvl(can_debitos,0) + decode(v_imp_efectivo,0,0,1),
                 tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_imp_che_o_bco,0),
                 sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_imp_che_o_bco,0),
                 estado = 1 -- abierto
           where nro_caja = to_number(v_nro_terminal)
             and cod_moneda = v_cod_moneda
             and fecha = v_fec_actual;
          if sql%notfound then
             insert into cj_controles
               (nro_caja, cod_moneda, fecha, estado,
                mto_apertura, ini_che_otr_bco, cod_usu_actual,
                tot_che_nue_bco, sal_actual, tot_debitos,
                can_debitos, tot_che_otr_bco, sal_che_otr_bco)
             select
                v_nro_terminal, v_cod_moneda, v_fec_actual, 1,
                0, 0, v_cod_usuario,
                v_imp_che_n_bco, v_imp_efectivo, v_imp_efectivo,
                decode(v_imp_efectivo,0,0,1), v_imp_che_o_bco,
                v_imp_che_o_bco from dual;
          end if;
          if v_imp_debito > 0 then
             if v_cod_respuesta = paw_bce.v_cod_aprobado then
                -- valido la duplicación de pago de préstamos
                if fu_ver_transaccion(503, v_cod_tra_padre, v_nro_cta_debito, v_imp_debito) = 'S' then
                  v_cod_respuesta := paw_bce.v_cod_mov_ya_ingresado;
                end if;
             end if;             

             -- genero el movimiento respectivo
              begin
                select cod_moneda
                  into v_cod_mon_debito
                  from ge_cuentas
                 where nro_cuenta = v_nro_cta_debito;
                if v_cod_mon_debito <> v_cod_moneda then
                   v_cod_respuesta := paw_bce.v_cod_tra_invalida;
                end if;
              exception
                 when others then
                    v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
              end;
              if v_cod_respuesta = paw_bce.v_cod_aprobado then
                  -- seteo las variables para el debito
                  pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                                            v_fec_valor,
                                            v_cod_tra_padre, 'N', 'N',
                                            v_nro_secuencia,
                                            null, v_cod_ofi_origen, 9, 91);
                  -- esta la cuenta en condiciones, verifico el horario
                  lp_ver_horario;
                  -- realizo el debito respectivo
                  pag_cta.PR_ACT_OPERACION(v_nro_cta_debito, v_hor_actual,'D',
                                           v_cod_mon_debito, v_imp_debito,
                                           v_cod_tra_padre, 503, v_nro_operacion,
                                           null, v_cod_ofi_origen, 9, 91,
                                           null, null, 'Pago de Prestamos',
                                           'N', v_nro_secuencia, v_fec_valor,
                                           null, null, null);
                 if nvl(pag_cta.g_cod_error,0) <> 0 then
                    -- hubo error en el debito
                    v_cod_respuesta := paw_bce.v_cod_tra_invalida;
                 else
                    -- veo si el prestamo, debe quedar como pagado
                    if v_horario in ('T','N') then
                       -- insert into pr_cobros_noc para procesar en el inicio de dia.
                       insert into pr_cobros_noc
                       (nro_cuenta, nro_cuota_desde, nro_cuota_hasta,
                        fecha, hora, estado, mto_cobrado, cod_ofi_origen,
                        cod_mod_padre, cod_mad_padre, cod_tra_padre,
                        nro_secuencia)
                       values
                       (v_nro_cuenta, v_nro_cuota_desde, v_nro_cuota_hasta,
                        v_fec_actual, v_hor_actual, 'I', v_tot_pago, v_cod_ofi_origen,
                        9, 91, v_cod_tra_padre, v_nro_secuencia);
                       --
                    else
                       -- horario normal, se aplica el prestamo
                       pap_pre.pr_cob_prestamo(v_nro_cuenta,
                                               v_tot_pago,
                                               'N',
                                               v_cod_ofi_origen,
                                               v_nro_cuota_desde,
                                               v_nro_cuota_hasta,
                                              'Pago de Cuota', --concepto
                                               v_fec_actual,
                                               v_hor_actual,
                                               v_nro_secuencia,
                                               v_cod_tra_padre,
                                               9,
                                               91,
                                               'N');
                    end if;
                 end if ;
              end if;
          end if;
       end if;
     end if;
     return null;
  else
     return null;  -- nada
  end if;
  return null;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 031 - pago de tarjetas de credito


-- 032 - pago de tarjetas de credito
function fu_pro_operacion_032(p_parametros in varchar2,
                              p_nro_cta_debito  in varchar2 default null,
                              p_monto           in number   default null,
                              p_nro_tarjeta     in varchar2 default null,
                              p_modo            in varchar2 default null)
  return clob is
-- datos recibidos
v_nro_tarjeta     varchar2(16); -- nro de tarjeta a pagar
v_modo            varchar2(3);   -- modo S/V/C
-- datos a responder
v_detalles        clob := null;   -- datos de las cuentas
-- variables
v_nro_cuenta      varchar2(17);
v_embozado        varchar(35);
v_tip_tarjeta     varchar2(35);
v_cod_moneda      varchar2(03);
v_mto_pag_minimo  number(18,2);
v_deu_ult_cierre  number(18,2);
v_deu_actual      number(18,2);
v_fec_ult_cierre  date;
v_cod_mod_cta     number(4);
v_cod_mad_cta     number(4);
v_cod_ofi_cta     number(4);
v_cod_retencion   number(4);     -- codigo de retencion
v_fec_fin_retencion date;        -- fecha final de la retencion
--
v_cod_tra_padre   number(4) := 250;
v_cod_transaccion number(4);
v_nro_cta_debito  varchar2(17);
v_cod_mon_debito  varchar2(4);
v_nro_sobre       number(10);
v_imp_efectivo    number(18,2) := 0;   -- efectivo
v_imp_che_n_bco   number(18,2) := 0;  -- che.ntro.bco
v_imp_che_o_bco   number(18,2) := 0; -- che otros bcos.
v_imp_debito      number(18,2) := 0;   -- debito
v_tot_pago        number(18,2) := 0;   -- total
--
v_cta_for_debito  varchar2(17);  -- cuenta formateada
v_est_cta_debito  varchar2(1);   -- estado de la cuenta
v_cod_mod_debito  number(4);     -- modulo de la cuenta
v_cod_mad_debito  number(4);     -- modalidad de la cuenta
v_cod_ofi_debito  number(4);     -- oficina de la cuenta
v_nvo_est_debito  varchar2(1) := null; -- cambio de estado de cuenta
v_cot_debito      number(18,2) := null;
v_nom_cta_debito  varchar2(100);
v_cotizacion      number(18,4) := null;
--v_nro_cta_tarjeta varchar2(20);
v_nro_documento   number(15);
-- para control de límites
v_res_limite      varchar2(2);
--
begin
  if nvl(p_modo,'x') = 'A' then
     -- viene de confirmación de una autorización
     v_nro_cta_debito  := p_nro_cta_debito;
     v_imp_debito      := p_monto;
     v_nro_tarjeta     := p_nro_tarjeta;
     v_modo            := p_modo;
  else
     v_nro_tarjeta     := trim(substr(p_parametros,66,16)); -- nro de tarjeta a pagar
     v_modo            := substr(p_parametros,82,1);   -- modo S/V/C
     -- 1. valido la clave del cliente
     pr_val_clave(p_parametros);
     if v_modo = 'C' and v_can_aut_requeridas = 0 then
        -- se confirma directamente la operación, porque no requiere autorización
        v_modo := 'A'; -- CONFIRMACION
     end if;
  end if;
  -- Verifica los permisos solo cuando es por HB, por TAS no se debe controlar
  if fu_caj_homebanking(v_nro_terminal) = 'S' /*paw_bce.v_nro_terminal = '999'*/ then
     if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(p_modo,'x') <> 'A' then
        v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '032');
        if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
           v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
        end if;
     end if;        
  end if;
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     begin
       pag_cta.pr_obt_cuenta(PAT_IMP.FU_OBT_NRO_CUENTA(v_nro_tarjeta)); -- JIRA-1717
       if pag_cta.G_COD_ERROR <> 0 then
          v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
       end if;
       if pag_cta.g_ctas.estado not in ('B','N') then -- JIRA-1717
          v_cod_respuesta := paw_bce.v_cod_cta_cancelada;
       end if;
       v_nro_cuenta  := pag_cta.g_ctas.nro_cuenta;
       v_tip_tarjeta := fug_obt_des_modalidad(pag_cta.g_ctas.cod_modalidad);
       v_cod_moneda  := pag_cta.g_ctas.cod_moneda;
       v_cod_mod_cta := pag_cta.g_ctas.cod_modulo;
       v_cod_mad_cta := pag_cta.g_ctas.cod_modalidad;
       v_cod_ofi_cta :=pag_cta.g_ctas.cod_oficina;
       PAT_IMP.PR_OBT_DEU_TARJETA(v_nro_cuenta,v_nro_tarjeta,v_mto_pag_minimo,
                     v_deu_ult_cierre,v_deu_actual,v_fec_ult_cierre,v_embozado); -- JIRA-1717
     exception
        when no_data_found then
           v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
     end;

  end if;
 ---- 
  if v_cod_mad_cta=55 then
    v_cod_respuesta := paw_bce.v_cod_cta_invalida;
  end if;
  
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     if v_modo = 'S' then -- selección de datos
       -- busco las cuentas de débito
       if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(p_clave,'x') != 'a010yzp89c' then
          v_detalles := fu_pro_operacion_011(p_parametros, 'D',v_cod_moneda,'032');
       else
          v_detalles := lf_for_number(0,3);  -- sin cuentas de débito
       end if;
       return lf_for_char(v_nro_tarjeta,17)||
              lf_for_char(v_embozado,35)||
              lf_for_char(v_tip_tarjeta,35)||
              lf_for_char(rpad(v_cod_moneda,3,'.'),3)||
              lf_for_money(v_mto_pag_minimo,16)||
              lf_for_money(v_deu_ult_cierre,16)||
              lf_for_money(v_deu_actual,16)||
              lf_for_date(v_fec_ult_cierre)||
              v_detalles;
     elsif v_modo in ('V','C','A') then  -- validación o confirmación O AUTORIZACIÓN
        -- esta la cuenta en condiciones, verifico el horario del depósito
        lp_ver_horario;
        if nvl(p_modo,'x') <> 'A' then
        -- verifico la validez de los montos
        begin
          v_nro_cta_debito := trim(substr(p_parametros,83,17));
          if v_nro_cta_debito is not null then
            if (instr(v_nro_cta_debito,'-') > 0 or instr(v_nro_cta_debito,' ') > 0) then
               -- se extrae los guiones de la cuenta
               v_nro_cta_debito := to_number(substr(v_nro_cta_debito,7));
            end if;
          end if;
          v_nro_sobre      := trim(substr(p_parametros,100,10));
          v_imp_efectivo   := nvl(to_number(replace(trim(substr(p_parametros,110,18)),',','.')),0);   -- efectivo
          v_imp_che_n_bco  := nvl(to_number(replace(trim(substr(p_parametros,128,18)),',','.')),0);  -- che.ntro.bco
          v_imp_che_o_bco  := nvl(to_number(replace(trim(substr(p_parametros,146,18)),',','.')),0);  -- che otros bcos.
          v_imp_debito     := nvl(to_number(replace(trim(substr(p_parametros,164,18)),',','.')),0);   -- total
          v_tot_pago       := nvl(to_number(replace(trim(substr(p_parametros,182,18)),',','.')),0);   -- total
          if v_cod_moneda = v_cod_mon_local then
             if v_imp_efectivo <> trunc(v_imp_efectivo) or
                v_imp_che_n_bco <> trunc(v_imp_che_n_bco) or
                v_imp_che_o_bco <> trunc(v_imp_che_o_bco)  or
                v_imp_debito <> trunc(v_imp_debito) then
                -- monto con decimales y en guaranies no permite
                v_cod_respuesta := paw_bce.v_cod_mto_invalido;
             elsif nvl(v_imp_efectivo,0) + nvl(v_imp_che_n_bco,0) +
                nvl(v_imp_che_o_bco,0) + nvl(v_imp_debito,0) <> nvl(v_tot_pago,0) then
                -- total depositado invalido
                v_cod_respuesta := paw_bce.v_cod_tot_invalido;
             end if;
          end if;
        exception
          when others then
             -- monto invalido
             v_cod_respuesta := paw_bce.v_cod_mto_invalido;
        end;
        else -- en p_modo a, se carga directamente los datos
           v_nro_sobre     := 0;
           v_imp_efectivo  := 0;
           v_imp_che_n_bco := 0;
           v_imp_che_o_bco := 0;
           v_tot_pago := v_imp_debito;
        end if;
        if v_cod_respuesta = paw_bce.v_cod_aprobado and v_nro_cta_debito is not null then
           if lf_val_cta_origen(v_nro_cta_debito,nvl(v_cod_per_empresa,v_cod_persona)) = 'N' then
              -- no es una cuenta del cliente
              v_cod_respuesta := paw_bce.v_cod_cta_invalida;
           end if;
        end if;
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
          --
          if v_nro_cta_debito is not null then
              pr_val_cta_debito( v_nro_cta_debito,
                                 v_cod_tra_padre,
                                 v_imp_debito,
                                 v_cod_mon_debito,
                                 v_cod_mod_debito,
                                 v_cod_mad_debito,
                                 v_cod_ofi_debito,
                                 v_cta_for_debito,
                                 v_nom_cta_debito);
              if v_cod_moneda <> v_cod_mon_debito then
                 -- moneda diferentes
                 v_cod_respuesta := paw_bce.v_cod_tra_invalida;
              end if;
          else
             if fu_caj_homebanking(v_nro_terminal) = 'S' /*paw_bce.v_nro_terminal = '999'*/ then -- si el pago es por HB, debe tener una cuenta debito, si es por TAS puede o no tener
                v_cod_respuesta := paw_bce.v_cod_tra_invalida;
             end if;
          end if;
          if v_modo = 'C' and v_can_aut_requeridas = 0 then
             -- se confirma directamente la operación, porque no requiere autorización
             v_modo := 'A'; -- CONFIRMACION
          end if;
          if v_imp_debito > 0 and v_modo = 'V' then
             -- verifico que no exista pendiente
             if v_cod_respuesta = paw_bce.v_cod_aprobado then
               if fu_ver_mov_pendiente(v_cod_per_empresa, v_nro_cta_debito, v_nro_cuenta /*v_nro_cta_tarjeta*/, v_imp_debito, '032') = 'S' then
                 v_cod_respuesta := paw_bce.v_cod_pag_pendiente;
               end if;
             end if;
             -- verifico la duplicación de pago
             if v_cod_respuesta = paw_bce.v_cod_aprobado then
               if fu_ver_transaccion(503, v_cod_tra_padre, v_nro_cta_debito, v_imp_debito) = 'S' then
                 v_cod_respuesta := paw_bce.v_cod_mov_ya_ingresado;
               end if;
             end if;
          end if;
          -- 10/04/2012 : Verifico que la cta de débito tenga límite para la operación
          -- se agrega monitoreo de límite global de pago de tarjeta
          if v_cod_respuesta = paw_bce.v_cod_aprobado then
             if nvl(p_modo,'x') <> 'A' and v_modo IN ('C', 'V', 'A') and fu_caj_homebanking(v_nro_terminal) = 'S' /*paw_bce.v_nro_terminal = '999'*/ then -- solo si es por HB
                v_res_limite := fu_obt_limite('032',
                            nvl(v_cod_per_empresa,v_cod_persona),
                            v_nro_cta_debito,
                            v_cod_mon_debito,
                            503,
                            v_cod_tra_padre,
                            v_tot_pago,
                            v_modo );
             end if;
          end if;
          -- 13/04/2012 : se verifica la clave transaccional y/o token
          -- segun informe de fu_obt_limite, solo al confirmar o autorizar la operación
          if v_cod_respuesta = paw_bce.v_cod_aprobado then
             if v_modo IN ('C', 'A') and nvl(p_modo,'x') <> 'A' then

                if v_res_limite IN ('10', '11') then -- clave transaccional requerida
                   v_cod_respuesta := lf_obt_cla_validar(p_parametros,v_cod_persona,v_cod_per_empresa,202,'T');
                end if;

                if v_cod_respuesta = paw_bce.v_cod_aprobado then
                   if v_res_limite IN ('01', '11') then -- token requerido
                      v_cod_respuesta := fu_obt_tok_validar(p_parametros,v_cod_persona,v_cod_per_empresa,234, v_modo);
                   end if;
                end if;
             end if;
          end if;
          --
          if v_modo = 'V' then -- solo se valida
             -- devolvemos la respuesta
             return  lpad(ltrim(lf_for_money(v_cotizacion,16)),16,'0')||
                     lf_for_char(v_cta_for_debito,17)||
                     lf_for_char(v_nom_cta_debito,50)||
                     lf_for_char(rpad(v_cod_mon_debito,3,'.'),3)||
                     lf_for_money(v_imp_debito,16)||
                     lf_for_char(v_nro_tarjeta,17)||
                     lf_for_char(v_embozado,50)||
                     lf_for_char(rpad(v_cod_moneda,3,'.'),3)||
                     lf_for_money(v_imp_debito,16)||
                     -- para control de límite global
                     lf_for_char(v_res_limite,2);
                     --
          elsif v_modo = 'C' and v_cod_respuesta = paw_bce.v_cod_aprobado then -- grabación en pendiente
              -- registro del movimiento
              lp_reg_operacion(v_nro_cuenta/*v_nro_cta_tarjeta*/ /*p_nro_cuenta*/,
                               v_cod_moneda /*p_cod_moneda */,
                               v_tot_pago /*p_monto*/,
                               v_nro_cta_debito /*p_nro_cta_contra*/,
                               null,
                               'Efectivo',
                               v_imp_efectivo,
                               'Cheques',
                                v_imp_che_n_bco + v_imp_che_o_bco,
                               'Nro.Tarj: '||v_nro_tarjeta
                            );
              if v_imp_debito > 0 then
                --- inserto el movimiento pendiente de autorizacion
                select s_nro_documento.nextval into v_nro_documento from dual;
                insert into bw_mov_pendientes
                  (nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda,
                   descripcion, monto, nro_cta_contra,etiqueta, dato,
                   estado,can_aut_requeridas, can_aut_faltantes, cod_per_ingreso, mto_contra)
                values
                   (v_nro_documento,nvl(v_cod_per_empresa,v_cod_persona),sysdate,'032',v_nro_cta_debito,v_cod_moneda,
                    'Pago de Tarjetas de Credito',v_imp_debito, v_nro_cuenta/*v_nro_cta_tarjeta*/,'Nro. de Tarjeta',v_nro_tarjeta,
                    'P', v_can_aut_requeridas, v_can_aut_requeridas, v_cod_persona, v_imp_debito
                   );
                return lf_for_number(v_can_aut_requeridas,3)||lf_for_number(v_nro_documento,15);
              else
                 v_cod_respuesta := paw_bce.v_cod_mto_invalido;
              end if;
          end if;
          --- ESTO PARA CONFIRMACION  cuando es el modo 'A' ----
          if v_cod_respuesta = paw_bce.v_cod_aprobado then
             -- registro del movimiento
             lp_reg_operacion(v_nro_cuenta/*v_nro_cta_tarjeta*/ /*p_nro_cuenta*/,
                           v_cod_moneda /*p_cod_moneda */,
                           v_tot_pago /*p_monto*/,
                           v_nro_cta_debito /*p_nro_cta_contra*/,
                           null,
                           'Efectivo',
                           v_imp_efectivo,
                           'Cheques',
                            v_imp_che_n_bco + v_imp_che_o_bco,
                           'Nro.Tarj: '||v_nro_tarjeta
                        );
          -- sigue sin problemas hasta aqui, ya puedo grabar
          if v_imp_efectivo > 0 then
             -- importe en efectivo
              v_cod_tra_padre   := 250;
              v_cod_transaccion := 613;
              -- obtengo el codigo y fin de retencion
              pag_cta.pr_obt_retencion(v_fec_actual,
                                       v_nro_cuenta,
                                       v_cod_mod_cta,
                                       v_cod_mad_cta,
                                       v_cod_transaccion,
                                       v_cod_moneda,
                                       v_cod_retencion,
                                       v_fec_fin_retencion);
              -- genero el movimiento respectivo
              lp_ins_movimiento( v_cod_mod_cta,
                                 v_cod_mad_cta,
                                 v_cod_ofi_cta,
                                 v_nro_cuenta,
                                 v_cod_moneda,
                                 v_cod_tra_padre,
                                 v_cod_transaccion,
                                 v_nro_sobre,
                                 v_imp_efectivo,
                                 'E', -- EFECTIVO
                                 v_es_mov_noc,
                                 v_cod_retencion,
                                 v_fec_fin_retencion);
              -- inserto el movimiento de cobro de tarjetas
/*              insert into ta_cobros
                  (nro_cuenta, nro_tarjeta, nro_cta_debito,
                   fec_proceso, monto, estado, fec_valor, observacion,
                   hora, cod_usuario)
              values
                  (v_nro_cuenta, v_nro_tarjeta, null, v_fec_actual, v_imp_efectivo,
                   'C', nvl(v_fec_fin_retencion,v_fec_valor), 'Pago Efectivo x Bca.Electronica',
                   v_hor_actual, v_cod_usuario);*/
          end if;
          if v_imp_che_n_bco > 0 then
             -- importe en cheques ntro banco
              v_cod_tra_padre   := 250;
              v_cod_transaccion := 614;
              -- obtengo el codigo y fin de retencion
              pag_cta.pr_obt_retencion(v_fec_actual,
                                       v_nro_cuenta,
                                       v_cod_mod_cta,
                                       v_cod_mad_cta,
                                       v_cod_transaccion,
                                       v_cod_moneda,
                                       v_cod_retencion,
                                       v_fec_fin_retencion);
              -- genero el movimiento respectivo
              lp_ins_movimiento( v_cod_mod_cta,
                                 v_cod_mad_cta,
                                 v_cod_ofi_cta,
                                 v_nro_cuenta,
                                 v_cod_moneda,
                                 v_cod_tra_padre,
                                 v_cod_transaccion,
                                 v_nro_sobre,
                                 v_imp_che_n_bco,
                                 'C', -- cheque ntro bco
                                 v_es_mov_noc,
                                 v_cod_retencion,
                                 v_fec_fin_retencion);
          end if;
          if v_imp_che_o_bco > 0 then
             -- importe en cheques otros bancos
              v_cod_tra_padre   := 250;
              v_imp_alt_valor := fug_obt_pardinamico('MTO_CHE_RET_CERO',null,null,v_cod_moneda,null,null );
              IF v_cod_moneda = v_cod_mon_local THEN 
                 /*if v_imp_che_o_bco >= v_imp_alt_valor then
                   if v_horario = 'D' and v_hor_actual > v_hor_cie_cheques then
                       -- se graba ya como cheques 48 hs de retencion
                      v_cod_transaccion := 632;
                      v_tip_monto       := 'S';
                   else
                      v_cod_transaccion := 607;                
                      v_tip_monto       := 'O';
                   end if;
                else*/              
                  if v_horario = 'D' and v_hor_actual > v_hor_cie_cheques then
                    -- se graba ya como cheques 48 hs de retencion
                    v_cod_transaccion := 632;
                    v_tip_monto       := 'S';
                  else
                    v_cod_transaccion := 615;
                    v_tip_monto       := 'T';
                  end if;
                --end if;
              ELSE
                 v_cod_transaccion := 615;
                 v_tip_monto       := 'T';  
                 IF v_horario = 'D' and v_hor_actual > v_hor_cie_cheques THEN
                    -- se graba ya como cheques 48 hs de retencion
                    v_cod_transaccion := 632;
                    v_tip_monto       := 'S';
                 END IF;
              END IF;    
              -- obtengo el codigo y fin de retencion
              pag_cta.pr_obt_retencion(v_fec_actual,
                                       v_nro_cuenta,
                                       v_cod_mod_cta,
                                       v_cod_mad_cta,
                                       v_cod_transaccion,
                                       v_cod_moneda,
                                       v_cod_retencion,
                                       v_fec_fin_retencion);
              -- genero el movimiento respectivo
              lp_ins_movimiento( v_cod_mod_cta,
                                 v_cod_mad_cta,
                                 v_cod_ofi_cta,
                                 v_nro_cuenta,
                                 v_cod_moneda,
                                 v_cod_tra_padre,
                                 v_cod_transaccion,
                                 v_nro_sobre,
                                 v_imp_che_o_bco,
                                 v_tip_monto, -- cheque otros bcos
                                 v_es_mov_noc,
                                 v_cod_retencion,
                                 v_fec_fin_retencion);
          end if;
          if nvl(v_imp_efectivo,0) + nvl(v_imp_che_n_bco,0) + nvl(v_imp_che_o_bco,0) > 0 then
              -- actualizo el control de caja
              update cj_controles
                 set tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_imp_che_n_bco,0),
                     sal_actual = nvl(sal_actual,0) + nvl(v_imp_efectivo,0),
                     tot_debitos = nvl(tot_debitos,0) + nvl(v_imp_efectivo,0),
                     can_debitos = nvl(can_debitos,0) + decode(v_imp_efectivo,0,0,1),
                     tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_imp_che_o_bco,0),
                     sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_imp_che_o_bco,0),
                     estado = 1 -- abierto
               where nro_caja = to_number(v_nro_terminal)
                 and cod_moneda = v_cod_moneda
                 and fecha = v_fec_actual;
              if sql%notfound then
                 insert into cj_controles
                   (nro_caja, cod_moneda, fecha, estado,
                    mto_apertura, ini_che_otr_bco, cod_usu_actual,
                    tot_che_nue_bco, sal_actual, tot_debitos,
                    can_debitos, tot_che_otr_bco, sal_che_otr_bco)
                 select
                    v_nro_terminal, v_cod_moneda, v_fec_actual, 1,
                    0, 0, v_cod_usuario,
                    v_imp_che_n_bco, v_imp_efectivo, v_imp_efectivo,
                    decode(v_imp_efectivo,0,0,1), v_imp_che_o_bco,
                    v_imp_che_o_bco from dual;
              end if;
          end if;
          if v_imp_debito > 0 then
             if v_cod_respuesta = paw_bce.v_cod_aprobado then
                -- verifico sino hay pagos con el mismo monto
                if fu_ver_transaccion(503, v_cod_tra_padre, v_nro_cta_debito, v_imp_debito) = 'S' then
                  v_cod_respuesta := paw_bce.v_cod_mov_ya_ingresado;
                end if;
             end if;

             if v_cod_respuesta = paw_bce.v_cod_aprobado then
                 -- genero el movimiento respectivo
                 lp_ins_movimiento( v_cod_mod_cta,
                                    v_cod_mad_cta,
                                    v_cod_ofi_cta,
                                    v_nro_cuenta,
                                    v_cod_moneda,
                                    v_cod_tra_padre,
                                    978,
                                    v_nro_operacion,
                                    v_imp_debito,
                                    'N', -- no afecta a caja,es debito
                                    v_es_mov_noc,
                                    null,
                                    null,
                                    'Debito en Tarjeta por TAS/HB',
                                    null,
                                    5,
                                    51
                                    );
                  begin
                    select cod_moneda
                      into v_cod_mon_debito
                      from ge_cuentas
                     where nro_cuenta = v_nro_cta_debito;
                    if v_cod_mon_debito <> v_cod_moneda then
                       v_cod_respuesta := paw_bce.v_cod_tra_invalida;
                    end if;
                  exception
                     when others then
                        v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
                  end;
              end if;
              if v_cod_respuesta = paw_bce.v_cod_aprobado then
                  -- seteo las variables para el debito
                  pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                                            v_fec_valor,
                                            v_cod_tra_padre, 'N', 'N',
                                            v_nro_secuencia,
                                            null, v_cod_ofi_origen, 5, 51);
                  -- esta la cuenta en condiciones, verifico el horario
                  lp_ver_horario;
                  -- realizo el debito respectivo
                  pag_cta.PR_ACT_OPERACION(v_nro_cta_debito, v_hor_actual,'D',
                                           v_cod_mon_debito, v_imp_debito,
                                           v_cod_tra_padre, 503, v_nro_operacion,
                                           null, v_cod_ofi_origen, 5, 51,
                                           null, null, 'Pago de Tarjetas',
                                           'N', v_nro_secuencia, v_fec_valor,
                                           null, null, null);
                 if nvl(pag_cta.g_cod_error,0) <> 0 then
                    -- hubo error en el debito
                   -- v_cod_respuesta := paw_bce.v_cod_tra_invalida;
                   raise_application_error(-20010,'Error en Debito: '||pag_cta.G_MSJ_ERROR);
                 else
                   insert into ta_cobros
                     (nro_cuenta, nro_tarjeta, nro_cta_debito,
                      fec_proceso, monto, estado, fec_valor, observacion,
                      hora, cod_usuario)
                   values
                      (v_nro_cuenta, v_nro_tarjeta,v_nro_cta_debito, v_fec_actual, v_imp_debito,
                      'P', v_fec_actual, 'Debito en Cuenta x Bca.Electronica',
                       v_hor_actual, v_cod_usuario);
                 end if ;
              end if;
          end if;
          end if;
       end if;
     end if;
     return null;
  else
     return null;  -- nada
  end if;
  return null;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 032 - pago de tarjetas de credito

-- 033-validacion o confirmacion de Pago de despachos aduaneros
function fu_pro_operacion_033(p_parametros in varchar2,
                              p_nro_cta_debito  in varchar2 default null,
                              p_monto           in number   default null,
                              p_modo            in varchar2 default null,
                              p_msj_original    in varchar2 default null)
  return varchar2 is

-- Datos Recibidos del HB
v_nro_cta_debito  varchar2(16); -- nro de cuenta de debito
v_monto           number(18,2);   -- monto a transferir
v_modo            varchar2(1);    -- modo V-validacion o C-confirmacion
v_campo1          varchar2(16);   -- Ruc Importador
v_campo2          varchar2(16);   -- Ruc Despachante
v_tip_operacion   varchar2(3);    -- Tipo Operacion TDA o TID
v_nom_importador  varchar(100);
v_nom_despachante varchar(100);

v_mto_bol_total    number(18,2);  -- monto total de ticket
v_mto_bol_efectivo number(18,2);  -- monto efectivo de ticket
v_mto_bol_cheque   number(18,2);  -- monto cheque de ticket
v_etiqueta1        bw_movimientos.etiqueta%type;
v_etiqueta2        bw_movimientos.etiqueta2%type;
v_dato1            bw_movimientos.dato%type;
v_dato2            bw_movimientos.dato2%type;
v_descripcion      varchar2(100);
v_concepto         varchar2(35);
v_tip_agente       varchar2(5);

-- Variables
v_parametros      varchar2(1000);
v_cta_for_debito  varchar2(17);      -- Cuenta Debito formateada
v_cod_mon_debito  varchar2(3);       -- Moneda de la cuenta
v_est_cta_debito  varchar2(1);       -- Estado de la cuenta
v_cod_mod_debito  number(4);         -- Modulo de la cuenta
v_cod_mad_debito  number(4);         -- Modalidad de la cuenta
v_cod_ofi_debito  number(4);         -- Oficina de la cuenta
v_nvo_est_debito  varchar2(1) := null; -- cambio de estado de cuenta
v_nom_cta_debito  varchar2(100);     -- Nombre de la cuenta
v_cot_debito      number(18,2) := null;

v_nro_cta_credito varchar2(15);      -- Numero de Cuenta Credito
v_cta_for_credito varchar2(17);      -- Cuenta Credito formateada
v_cod_mon_credito varchar2(3);       -- Moneda de la cuenta
v_est_cta_credito varchar2(1);       -- Estado de la cuenta
v_cod_mod_credito number(4);         -- Modulo de la cuenta
v_cod_mad_credito number(4);         -- Modalidad de la cuenta
v_cod_ofi_credito number(4);         -- Oficina de la cuenta
v_nvo_est_credito varchar2(1) := null; -- cambio de estado de cuenta
v_nom_cta_credito varchar2(100);     -- Nombre de la Cta
v_cot_credito     number(18,4) := null;
v_sal_dis_credito number(18,2);

--Para Distintas monedas No habilitado todavia
v_mto_credito     number(18,2);
v_mto_equ_local   number(18) := null;
v_cotizacion      number(18,2) := null;

v_procesa         varchar2(1) := 'N'; -- indica si se puede o no procesar

-- Cobro de servicios
r_cobro           ge_cob_servicios%ROWTYPE;
v_nro_ope_cxs     ge_cob_servicios.nro_operacion%type;
v_cod_servicio    number(3);  -- Cod del Servicicio
v_tip_servicio    ge_cob_ser_parametros.tip_servicio%type;
v_cod_tra_padre   ge_cob_ser_parametros.cod_transaccion%type; -- Cod. transaccion padre
v_for_campo1      ge_cob_ser_parametros.for_campo1%type;      -- Formato campo1
v_val_campo1      ge_cob_ser_parametros.val_campo1%type;      -- Valida el Campo1
v_for_campo2      ge_cob_ser_parametros.for_campo2%type;      -- Formato campo2
v_val_campo2      ge_cob_ser_parametros.val_campo2%type;      -- Valida el Campo2
v_respuesta       varchar2(500);     -- Respuestas de la DNA y paquete de servicios
v_nro_documento   number(15);

-- para control de límites
v_res_limite      varchar2(2);
v_ini_param       number; -- inicio parametro de límite
v_ini_cla_tran    number; -- inicio parámetro de clave transaccional
v_ini_token       number; -- inicio parámetro de token
--
begin
  -- 0. inicializo la secuencia
  v_nro_secuencia := 0;
  if nvl(p_modo,'x') = 'A' then
     -- viene de confirmación de una autorización
     v_nro_cta_debito  := p_nro_cta_debito;
     v_monto           := p_monto;
     v_modo            := p_modo;
     v_parametros      := p_msj_original;
  else
     v_nro_cta_debito  := lf_obt_cta_limpia(substr(p_parametros,66,16)); -- nro de cuenta de débito
     v_monto           := nvl(to_number(replace(trim(substr(p_parametros,82,16)),',','.')),0);   -- monto a transferir
     v_modo            := substr(p_parametros,98,1);    -- modo V-validación o C-confirmación
     v_parametros      := p_parametros;
     -- 1. valido la clave del cliente
     pr_val_clave(p_parametros);
     if v_modo = 'C' and v_can_aut_requeridas = 0 then
        -- se confirma directamente la operación, porque no requiere autorización
        v_modo := 'A'; -- CONFIRMACION
     end if;
  end if;

  v_tip_operacion := substr(v_parametros,99,3); -- Tipo Operación TDA, TID o TCA

  if v_tip_operacion in ('TDA', 'TID') then
    v_campo1          := trim(substr(v_parametros,102,15));   -- Ruc Importador
    v_campo2          := trim(substr(v_parametros,117,15));   -- Ruc Despachante
    v_nom_importador  := substr(v_parametros,132,30); -- Nombre Importador
    v_nom_despachante := substr(v_parametros,162,30); -- Nombre Despachante
  elsif v_tip_operacion in ('TCA') then
    v_campo1          := trim(substr(v_parametros,102,16));   -- Nro Ticket
    v_campo2          := trim(substr(v_parametros,118,15));   -- Ruc Despachante
    v_nom_despachante := substr(v_parametros,133,30); -- Nombre Despachante
  elsif v_tip_operacion in ('TLE') then
    v_campo1          := trim(substr(v_parametros,102,16));   -- Nro Ticket
    v_campo2          := trim(substr(v_parametros,118,15));   -- Ruc Solicitante
    v_nom_despachante := substr(v_parametros,133,30); -- Nombre Solicitante
  end if;
  
  -- limpiamos los parametros
  v_campo1 := REGEXP_REPLACE(TRIM(v_campo1), '([^[:alnum:]])', '');
  v_campo2 := REGEXP_REPLACE(TRIM(v_campo2), '([^[:alnum:]])', '');

  if v_tip_operacion = 'TDA' then
    v_descripcion := 'Pago de Despachos';
    v_etiqueta1 := 'Importador';
    v_etiqueta2 := 'Despachante';
  elsif v_tip_operacion = 'TID' then
    v_descripcion := 'Pago de IVA Despachante';
    v_etiqueta2 := 'Despachante';
  elsif v_tip_operacion = 'TCA' then
    v_descripcion := 'Pago de Canon Informatico';
    v_etiqueta1 := 'Nro. Ticket';
    v_etiqueta2 := 'Despachante';
  else -- TLE
    v_descripcion := 'Liquidacion Pago de Expedientes';
    v_etiqueta1 := 'Nro. Ticket';
    v_etiqueta2 := 'Solicitante';
  end if;


  v_cod_servicio := fug_obt_pardinamico('COD_SER_SOFIA_' || v_tip_operacion);

  --Verifica los permisos  
  if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(p_modo,'x') <> 'A' then
     v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '033');
     if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
        v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
     end if;
  end if;      

  -- 2. busco los datos de la cuentas

  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    -- Busco el cobro de servicio
    begin
      select nro_cuenta, cod_transaccion, tip_servicio,
             for_campo1, val_campo1, for_campo2, val_campo2
       into v_nro_cta_credito, v_cod_tra_padre, v_tip_servicio,
            v_for_campo1, v_val_campo1, v_for_campo2, v_val_campo2
       from ge_cob_ser_parametros f
      where cod_servicio = v_cod_servicio;
    exception
        when others then
           v_cod_respuesta  := paw_bce.v_cod_ser_inexistente;
    end;

    if v_cod_respuesta = paw_bce.v_cod_aprobado then
      -- Validacion de los Campos de Ruc (Importador/Despachante)
      if v_tip_operacion = 'TDA' then
        pag_Ser.lp_val_referencia(v_campo1,v_for_campo1,v_val_campo1);
        if pag_ser.fu_obt_error(v_respuesta,v_respuesta) then
           v_cod_respuesta := paw_bce.v_cod_dat_invalido;
        else
           v_cod_respuesta := paw_bce.v_cod_aprobado;
        end if;
      end if;
      if v_tip_operacion in ('TDA') then
        pag_Ser.lp_val_referencia(v_campo2,v_for_campo2,v_val_campo2);
        if pag_ser.fu_obt_error(v_respuesta,v_respuesta) then
           v_cod_respuesta := paw_bce.v_cod_dat_invalido;
        else
           v_cod_respuesta := paw_bce.v_cod_aprobado;
        end if;
      end if;
      if v_tip_operacion in ('TID') then
        pag_Ser.lp_val_referencia(v_campo2,v_for_campo1,v_val_campo1);
        if pag_ser.fu_obt_error(v_respuesta,v_respuesta) then
           v_cod_respuesta := paw_bce.v_cod_dat_invalido;
        else
           v_cod_respuesta := paw_bce.v_cod_aprobado;
        end if;
      end if;

      -- La cuenta de debito no puede ser igual a la de credito
      if v_nro_cta_debito = v_nro_cta_credito then
         v_cod_respuesta := paw_bce.v_cod_tra_invalida;
      else
         pr_val_cta_debito( v_nro_cta_debito,
                            v_cod_tra_padre,
                            v_monto,
                            v_cod_mon_debito,
                            v_cod_mod_debito,
                            v_cod_mad_debito,
                            v_cod_ofi_debito,
                            v_cta_for_debito,
                            v_nom_cta_debito);
         if v_modo = 'C' and v_can_aut_requeridas = 0 then
           -- se confirma directamente la operacion, porque no requiere autorizacion
           v_modo := 'A'; -- CONFIRMACION
         end if;
      end if;
      if v_cod_respuesta = paw_bce.v_cod_aprobado and v_nro_cta_debito is not null then
         if lf_val_cta_origen(v_nro_cta_debito,nvl(v_cod_per_empresa,v_cod_persona)) = 'N' then
            -- no es una cuenta del cliente
            v_cod_respuesta := paw_bce.v_cod_cta_invalida;
         end if;
      end if;
      -- Si la cuenta de Debito esta Ok continuo
      if v_cod_respuesta = paw_bce.v_cod_aprobado then
        -- verifico la cuenta de credito(La cuenta de la DNA)
        begin
            select a.cod_moneda, a.estado, cod_modalidad,
                   cod_modulo, cod_oficina,
                   fug_cta_formateada(cod_modulo, cod_modalidad, cod_oficina,nro_cuenta, cod_moneda) cta_formateada,
                   denominacion
              into v_cod_mon_credito,
                   v_est_cta_credito, v_cod_mad_credito,
                   v_cod_mod_credito, v_cod_ofi_credito,
                   v_cta_for_credito, v_nom_cta_credito
              from ge_cuentas a
             where a.nro_cuenta = v_nro_cta_credito; -- contiene el nro de cuenta
        exception
            when no_data_found then
               v_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
            when too_many_rows then
               v_cod_respuesta  := paw_bce.v_cod_cta_duplicada;
            when others then
               v_cod_respuesta  := paw_bce.v_cod_cta_invalida;
        end;

        if v_cod_mon_credito <> v_cod_mon_debito then
           -- La cta de Debito debe ser la misma moneda que la cta de la DNA
           v_cod_respuesta := paw_bce.v_cod_mto_invalido;
        else
           v_mto_credito := v_monto;
        end if;

        if v_cod_respuesta = paw_bce.v_cod_aprobado then
          -- Validaciones de la Cuenta de Credito
          if v_mto_credito <= 0 then
             v_cod_respuesta := paw_bce.v_cod_mto_invalido;
          elsif v_cod_mad_credito not in (31,41) then
             v_cod_respuesta := paw_bce.v_cod_cta_invalida;
          elsif v_est_cta_credito not in ('A','I','N','S') then
             v_cod_respuesta := paw_bce.v_cod_cta_invalida;
          elsif pag_cta.fu_ver_tra_prohibida(v_nro_cta_credito,v_cod_tra_padre, 9, 91) = 'S' then
             v_cod_respuesta := paw_bce.v_cod_tra_prohibida;
          --elsif v_cod_mad_credito = 31 and pag_cta.fu_obt_cta_cte_comb(v_nro_cta_credito) is not null then
          --   v_cod_respuesta := paw_bce.v_cod_cta_invalida;
          -- RAMG: se anulo a pedido de L.Kublik 05/04/2010
          else
             pag_cta.pr_ver_operacion(v_nro_cta_credito,v_cod_tra_padre,9,91,'C',v_cod_mon_credito, v_mto_credito, v_cod_ofi_origen,
                                      v_cod_mod_credito, v_cod_mad_credito, v_nvo_est_credito, v_sal_dis_credito,
                                      v_procesa,602);
             if v_procesa = 'N' then
                -- no se puede debitar
                v_cod_respuesta := paw_bce.v_cod_cta_invalida;
             end if;
          end if;

          v_campo1 := nvl(v_campo1, '0');
          --*******************************************
          -- valido la duplicacion del Pago
          declare
              v_existe varchar2(1);
          begin
            begin
            select 'S'
             into v_existe
             from bw_mov_pendientes
            where cod_per_principal = v_cod_per_empresa
              and nro_cuenta = v_nro_cta_debito
              and monto = v_monto
              and estado = 'P'
              and cod_tip_mensaje = '033'
              and (dato like v_campo1 || '%' or dato2 like v_campo2 || '%')
              and rownum = 1;
            exception
              when too_many_rows then
                 v_existe := 'S';
              when others then
                 v_existe := 'N';
            end;
            
            if v_cod_respuesta = paw_bce.v_cod_aprobado then
               if v_existe = 'N' then
                  if fu_ver_transaccion(503, v_cod_tra_padre, v_nro_cta_debito, v_monto) = 'S' then
                    v_cod_respuesta := paw_bce.v_cod_mov_ya_ingresado;
                  end if;
               else
                  v_cod_respuesta := paw_bce.v_cod_mov_ya_ingresado;
               end if;
            end if;
           end;
        --****************************
        end if;
        -- CR: (2012-04-16) agregado para control de límites
        if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(p_modo, 'x') <> 'A' then
           if v_modo IN ('C', 'V', 'A') then
              v_res_limite := fu_obt_limite('033', 
                            nvl(v_cod_per_empresa,v_cod_persona), 
                            v_nro_cta_debito, 
                            v_cod_mon_debito, 
                            503, 
                            v_cod_tra_padre, 
                            v_monto,
                            v_modo );
           end if;
        end if;
          
        -- se verifica la clave transaccional y/o token 
        -- segun informe de fu_obt_limite, solo al confirmar o autorizar la operación
        if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(p_modo, 'x') <> 'A' then
           if v_modo IN ('C', 'A') then              
              v_ini_param    := 192;
              v_ini_cla_tran := 194;
              v_ini_token    := 226;
              
              if v_tip_operacion in ('TCA', 'TLE') then 
                 v_ini_param    := v_ini_param - 29;
                 v_ini_cla_tran := v_ini_cla_tran - 29;
                 v_ini_token    := v_ini_token - 29;
              end if;             
                             
              if v_res_limite IN ('10', '11') then -- clave transaccional requerida
                 v_cod_respuesta := lf_obt_cla_validar(p_parametros,v_cod_persona,v_cod_per_empresa,v_ini_cla_tran,'T');
              end if;
                
              if v_cod_respuesta = paw_bce.v_cod_aprobado then
                 if v_res_limite IN ('01', '11') then -- token requerido
                    v_cod_respuesta := fu_obt_tok_validar(p_parametros,v_cod_persona,v_cod_per_empresa,v_ini_token, v_modo);
                 end if;
              end if;
           end if;
        end if;
        --            

        if v_cod_respuesta = paw_bce.v_cod_aprobado then
           -- no hay problemas hasta aqui
           if v_modo = 'V' then -- validacion
            if v_tip_operacion in ('TDA', 'TID') then
              v_respuesta := pag_dna.fu_pro_deposito(v_tip_servicio,
                                              'R',
                                               ltrim(nvl(v_nro_terminal,999),'000'),
                                               To_number(v_nro_ope_cxs),
                                               v_campo1, -- Ruc Importador
                                               v_campo2, -- Ruc Despachante
                                               v_monto,
                                               v_nom_importador,
                                               v_nom_despachante);

              if v_respuesta not like '00-%' then
                 -- hay error
                 v_cod_respuesta := paw_bce.v_cod_rec_por_DNA;
                 return substr(v_respuesta,4,100);
              else
                 return lpad(ltrim(lf_for_money(v_cotizacion,16)),16,'0')||
                     lf_for_char(v_cta_for_debito,17)||
                     lf_for_char(v_nom_cta_debito,50)||
                     lf_for_char(rpad(v_cod_mon_debito,3,'.'),3)||
                     lf_for_money(v_monto,16)||
                     lf_for_char(v_campo1,15)||
                     lf_for_char(substr(v_nom_importador,1,30),30)||
                     lf_for_char(v_campo2,15)||
                     lf_for_char(substr(v_nom_despachante,1,30),30)||
                     -- agregado para limites
                     lf_for_char(v_res_limite, 2);
              end if;
            elsif v_tip_operacion = 'TCA' then

              v_respuesta := pag_dna.fu_pro_ticket(v_tip_servicio,
                                              'D',
                                               ltrim(nvl(v_nro_terminal,999),'000'),
                                               to_number(v_nro_ope_cxs),
                                               v_campo1, -- Nro. Ticket
                                               v_campo2, -- Ruc Despachante
                                               v_nom_despachante,
                                               v_mto_bol_total,
                                               v_mto_bol_efectivo,
                                               v_mto_bol_cheque);
              if v_respuesta not like '00-%' then
                 -- hay error
                 v_cod_respuesta := paw_bce.v_cod_rec_por_DNA;
                 return substr(v_respuesta,4,100);
              else
                 if v_mto_bol_cheque <> 0 or v_mto_bol_total <> v_mto_bol_efectivo then
                   v_cod_respuesta := paw_bce.v_cod_val_ticket_DNA;
                   return 'El Ticket no debe contener Valores en Cheques';
                 elsif v_mto_bol_total <> v_monto then
                   v_cod_respuesta := paw_bce.v_cod_val_ticket_DNA;
                   return 'El Monto Total del Ticket no coincide con el Monto Especificado';
                 else
                   return lpad(ltrim(lf_for_money(v_cotizacion,16)),16,'0')||
                       lf_for_char(v_cta_for_debito,17)||
                       lf_for_char(v_nom_cta_debito,50)||
                       lf_for_char(rpad(v_cod_mon_debito,3,'.'),3)||
                       lf_for_money(v_monto,16)||
                       lf_for_char(v_campo1,16)|| -- Nro. Ticket
                       lf_for_char(v_campo2,15)|| -- Ruc Despachante
                       lf_for_char(substr(v_nom_despachante,1,30),30)||
                       -- agregado para límites
                       lf_for_char(v_res_limite, 2);
                 end if;
              end if;
            else -- TLE
              v_respuesta := pag_dna.fu_pro_dna_ticket(v_tip_servicio,
                                              'Q',
                                               ltrim(nvl(v_nro_terminal,999),'000'),
                                               to_number(v_nro_ope_cxs),
                                               v_campo1, -- Nro. Ticket
                                               v_campo2, -- Ruc Solicitante
                                               v_nom_despachante,
                                               v_tip_agente,
                                               v_mto_bol_total);
              if v_respuesta not like '00-%' then
                 -- hay error
                 v_cod_respuesta := paw_bce.v_cod_rec_por_DNA;
                 return substr(v_respuesta,4,100);
              else
                 if v_mto_bol_total <> v_monto then
                   v_cod_respuesta := paw_bce.v_cod_val_ticket_DNA;
                   return 'El Monto Total del Ticket no coincide con el Monto Especificado';
                 else
                   return lpad(ltrim(lf_for_money(v_cotizacion,16)),16,'0')||
                       lf_for_char(v_cta_for_debito,17)||
                       lf_for_char(v_nom_cta_debito,50)||
                       lf_for_char(rpad(v_cod_mon_debito,3,'.'),3)||
                       lf_for_money(v_monto,16)||
                       lf_for_char(v_campo1,16)|| -- Nro. Ticket
                       lf_for_char(v_campo2,15)|| -- Ruc Despachante
                       lf_for_char(substr(v_nom_despachante,1,30),30)||
                       -- agregado para límites
                       lf_for_char(v_res_limite, 2);
                 end if;
              end if;
            end if;
           elsif v_modo = 'C' then -- grabacion en modo pendiente
              if v_tip_operacion in ('TDA', 'TID') then
                v_dato1 := substr(v_campo1 || ' - ' || v_nom_importador, 1, 50);
                v_dato2 := substr(v_campo2 || ' - ' || v_nom_despachante, 1, 50);
              elsif v_tip_operacion = 'TCA' then
                v_dato1 := v_campo1;
                v_dato2 := substr(v_campo2 || ' - ' || v_nom_despachante, 1, 50);
              else -- TLE
                v_dato1 := v_campo1;
                v_dato2 := substr(v_campo2 || ' - ' || v_nom_despachante, 1, 50);
              end if;

              -- grabación en pendiente
              -- registro del movimiento
              lp_reg_operacion(v_nro_cta_debito /*p_nro_cuenta*/,
                                v_cod_mon_debito /*p_cod_moneda */,
                                v_monto /*p_monto*/,
                                null /*p_nro_cta_contra*/,
                                null,
                                v_etiqueta1,
                                v_dato1,
                                v_etiqueta2,
                                v_dato2,
                                null, -- observacion
                                null,
                                p_parametros
                              );
              --- inserto el movimiento pendiente de autorización
              select s_nro_documento.nextval into v_nro_documento from dual;
              insert into bw_mov_pendientes
                (nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda,
                 descripcion, monto, etiqueta, dato, etiqueta2, dato2,
                 estado,can_aut_requeridas, can_aut_faltantes, cod_per_ingreso, referencia)
              values
                 (v_nro_documento,nvl(v_cod_per_empresa,v_cod_persona),sysdate,'033',v_nro_cta_debito,v_cod_mon_debito,
                  v_descripcion, v_monto, v_etiqueta1, v_dato1, v_etiqueta2, v_dato2,
                  'P', v_can_aut_requeridas, v_can_aut_requeridas, v_cod_persona, v_nro_operacion
                  );
              return lf_for_number(v_can_aut_requeridas,3)||lf_for_number(v_nro_documento,15);

           elsif v_modo = 'A' then -- confirmación
              if v_tip_operacion in ('TDA', 'TID') then
                v_dato1 := substr(v_campo1 || ' - ' || v_nom_importador, 1, 50);
                v_dato2 := substr(v_campo2 || ' - ' || v_nom_despachante, 1, 50);
                v_concepto := 'Imp: ' || v_campo1 || ' - ' || 'Desp: ' || v_campo2;
              elsif v_tip_operacion = 'TCA' then
                v_dato1 := v_campo1;
                v_dato2 := substr(v_campo2 || ' ' || v_nom_despachante, 1, 50);
                v_concepto := 'Bol.: ' || v_campo1;
              else -- TLE
                v_dato1 := v_campo1;
                v_dato2 := substr(v_campo2 || ' ' || v_nom_despachante, 1, 50);
                v_concepto := 'Bol.: ' || v_campo1;
              end if;

              -- registro del movimiento
              lp_reg_operacion(v_nro_cta_debito /*p_nro_cuenta*/,
                                v_cod_mon_debito /*p_cod_moneda */,
                                v_monto /*p_monto*/,
                                null /*p_nro_cta_contra*/,
                                null,
                                v_etiqueta1,
                                v_dato1,
                                v_etiqueta2,
                                v_dato2
                              );

              --- genero el numero de operación
              v_nro_ope_cxs := fue_obt_sig_secuencia('S_NRO_OPE_SOFIA');

              -- Cargar como cobro de servicio

              --- Insertar el cobro del servicio
              --- cargar los datos en r_cobro antes de pasarle como parámetro
              r_cobro.cod_servicio      := v_cod_servicio;
              r_cobro.tip_cobro         := 'E';
              r_cobro.nro_operacion     := v_nro_ope_cxs;
              r_cobro.fecha             := v_fec_actual;
              r_cobro.hora              := v_hor_actual;
              r_cobro.referencia1       := v_campo1;
              r_cobro.referencia2       := v_campo2;
              r_cobro.monto             := v_monto;
              r_cobro.mto_debito        := v_monto;
              r_cobro.nro_cta_debito    := v_nro_cta_debito;
              r_cobro.mto_efectivo      := 0;
              r_cobro.mto_che_nue_banco := 0;
              r_cobro.mto_che_otr_banco := 0;
              r_cobro.cod_moneda        := v_cod_mon_debito;
              r_cobro.cod_ofi_origen    := v_cod_ofi_debito;
              r_cobro.nro_caja          := to_number(v_nro_terminal);
              r_cobro.cod_usuario       := v_cod_usuario;
              r_cobro.estado            := 'P';
              r_cobro.referencia3       := substr(v_nom_importador,1,50);
              r_cobro.referencia4       := substr(v_nom_despachante,1,50);

              --Sino hubo ERROR se arma para grabar(insertar) el cobro en ge_cob_servicios
              if v_cod_respuesta = paw_bce.v_cod_aprobado then
                 pag_Ser.pr_ins_cobro(r_cobro, v_cod_tra_padre, 'E' );
                 if pag_ser.fu_obt_error(v_respuesta,v_respuesta) then
                    v_cod_respuesta := paw_bce.v_cod_otr_error;
                    return v_respuesta;
                 else
                    v_cod_respuesta := paw_bce.v_cod_aprobado;
                 end if;
              end if;

              --Sino hubo ERROR se arma para grabar(insertar) los Mvtos
              if v_cod_respuesta = paw_bce.v_cod_aprobado then
                 -- seteo las variables
                 v_nro_secuencia := 0;
                 pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                                           v_fec_valor,
                                           v_cod_tra_padre, 'N', 'N',
                                           v_nro_secuencia,
                                           null, v_cod_ofi_origen, 9, 91);
                 -- esta la cuenta en condiciones, verifico el horario
                 lp_ver_horario;
                 -- actualizo la cuenta de debito
                 if v_cod_mon_debito <> v_cod_mon_local and
                    v_cod_mon_debito <> v_cod_mon_credito and
                    v_cod_mon_credito = v_cod_mon_local then
                    v_cotizacion    := v_cot_debito;
                    v_mto_equ_local := v_mto_credito;
                 else
                    v_cotizacion     := null;
                    v_mto_equ_local  := null;
                 end if;
                 pag_cta.PR_ACT_OPERACION(v_nro_cta_debito, v_hor_actual,'D',
                                          v_cod_mon_debito, v_monto,
                                          v_cod_tra_padre, 503, v_nro_ope_cxs,
                                          v_cotizacion, v_cod_ofi_origen, 9, 91,
                                          null, null, v_concepto,
                                          'N', v_nro_secuencia, v_fec_valor,
                                          null, null, v_mto_equ_local);
                 if nvl(pag_cta.g_cod_error,0)= 0 then
                    if v_cod_mon_credito <> v_cod_mon_local and
                       v_cod_mon_debito <> v_cod_mon_credito and
                       v_cod_mon_debito = v_cod_mon_local then
                       v_cotizacion    := v_cot_credito;
                       v_mto_equ_local := v_monto;
                    else
                       v_cotizacion     := null;
                       v_mto_equ_local  := null;
                    end if;
                    pag_cta.PR_ACT_OPERACION(v_nro_cta_credito, v_hor_actual,'C',
                                             v_cod_mon_credito, v_mto_credito,
                                             v_cod_tra_padre, 602, v_nro_ope_cxs,
                                             v_cot_credito, v_cod_ofi_origen, 9, 91,
                                             null, null, v_concepto,
                                             'N', v_nro_secuencia, v_fec_valor,
                                             null, null, v_mto_equ_local);
                    if nvl(pag_cta.g_cod_error,0)<> 0 then
                      -- hubo algun error en el credito
                      v_cod_respuesta := paw_bce.v_cod_tra_invalida;
                    else
                      -- Si el Credito y el Debito fueron relizado envio a la Aduana
                      if v_cod_respuesta = paw_bce.v_cod_aprobado then
                        if v_tip_operacion in ('TDA', 'TID') then
                         v_respuesta := pag_dna.fu_pro_deposito(v_tip_servicio,
                                                                'C',
                                                                ltrim(nvl(v_nro_terminal,999),'000'),
                                                                To_number(v_nro_ope_cxs),
                                                                v_campo1, -- Ruc Importador
                                                                v_campo2, -- Ruc Despachante
                                                                v_monto,
                                                                v_nom_importador,
                                                                v_nom_despachante);
                         if v_respuesta not like '00-%' then
                            -- hay error
                            v_cod_respuesta := paw_bce.v_cod_rec_por_DNA;
                            return substr(v_respuesta,4,100);
                         end if;
                        elsif v_tip_operacion = 'TCA' then
                          v_respuesta := pag_dna.fu_pro_ticket(v_tip_servicio,
                                                          'T',
                                                           ltrim(nvl(v_nro_terminal,999),'000'),
                                                           to_number(v_nro_ope_cxs),
                                                           v_campo1, -- Nro. Ticket
                                                           v_campo2, -- Ruc Despachante
                                                           v_nom_despachante,
                                                           v_monto,
                                                           v_mto_bol_efectivo,
                                                           v_mto_bol_cheque);
                          if v_respuesta not like '00-%' then
                            -- hay error
                            v_cod_respuesta := paw_bce.v_cod_rec_por_DNA;
                            return substr(v_respuesta,4,100);
                          end if;
                        else -- TLE
                          v_respuesta := pag_dna.fu_pro_dna_ticket(v_tip_servicio,
                                                          'E',
                                                           ltrim(nvl(v_nro_terminal,999),'000'),
                                                           to_number(v_nro_ope_cxs),
                                                           v_campo1, -- Nro. Ticket
                                                           v_campo2, -- Ruc Solicitante
                                                           v_nom_despachante,
                                                           v_tip_agente,
                                                           v_monto);
                          if v_respuesta not like '00-%' then
                            -- hay error
                            v_cod_respuesta := paw_bce.v_cod_rec_por_DNA;
                            return substr(v_respuesta,4,100);
                          end if;
                        end if;
                      end if;
                    end if;
                else
                   -- hubo algun error en el debito
                   v_cod_respuesta := paw_bce.v_cod_tra_invalida;
                end if;
              end if;
           else
              -- No es del tipo V Validacion ni C Confirmacion
              v_cod_respuesta := paw_bce.v_cod_tra_invalida;
           end if;
        end if;
     end if;
    end if;
  end if;
  -- no se responde nada, solo se debe setear el v_cod_respuesta
  return null;
end;
-- fin de 033-Pago por Despachos Aduaneros

-- 036 - OMM - Validacion o Confirmacion de transferencias Interbancarias SNP
function fu_pro_operacion_036(p_parametros in varchar2,
                              p_modo            in varchar2 default null,
                              p_nro_referencia  in number   default null,
                              p_nro_cta_deb     in varchar2 default null,
                              p_mto_debito      in number   default null,
                              p_cot_debito      in number   default null,
                              p_nro_cta_cre     in varchar2 default null,
                              p_mto_credito     in number   default null,
                              p_cot_credito     in number   default null,
                              p_cod_mon_cre     in varchar2 default null,
                              p_fec_operacion   in date     default null)
  return clob is
--Variables Recibidas
v_nro_cta_debito       varchar2(16);
v_nro_cta_credito      varchar2(20);   -- cuenta de credito
v_modo                 varchar2(1) := substr(p_parametros, 66, 1); -- C(Cabecera), D(Detalle)
v_cod_mon_credito      varchar2(3);   -- moneda de la cuenta
v_cod_swift            varchar2(20) ;
v_nom_cliente          varchar2(100);
v_dir_cliente          varchar2(100);
v_nro_doc_credito      varchar2(20) := null;  -- nro de documento del acreditado
v_concepto             varchar2(100);
v_cargos               varchar2(1) ;
v_nom_beneficiario     varchar2(100) ;
v_dir_beneficiario     varchar2(100) ;
v_nro_ip               varchar2(20);
v_nro_contrato         number(7); -- Nro de Contrato de Cambio
v_tip_doc_beneficiario number(3) ;
v_mto_credito          number(18,2);
v_fec_operacion        date;
-- Variables Internas
v_cta_for_debito       varchar2(17);  -- cuenta formateada
v_cod_mon_debito       varchar2(3);   -- moneda de la cuenta
v_nom_cta_debito       varchar2(100);
v_nro_doc_cliente      varchar2(20);
v_procesa              varchar2(1) := 'N';    -- indica si se puede o no procesar
v_tip_cargos           varchar2(3) ;
v_estado               varchar2(1) := 'N' ; -- Estado del Periodo SNP
v_cta_pte_solicitante  varchar2(20); -- Nro de Cuenta Interbancaria
v_cta_pte_sol_bcp      varchar2(20);
v_tip_operacion        varchar2(3) ;
v_tip_mensaje          varchar2(1) ; -- C:Transferencia; T:Pago de TC
v_tip_movimiento       varchar2(1) ; -- D:Débito; C: Crédito
v_msj_swift            varchar2(4000) ;
v_cod_mod_debito       number(4);     -- Modulo de la cuenta
v_cod_mad_debito       number(4);     -- Modalidad de la cuenta
v_cod_mod_padre        number(4);     -- Modulo Padre
v_cod_mad_padre        number(4);     -- Modalidad Padre
v_cod_ofi_debito       number(4);     -- oficina de la cuenta
v_cot_debito           number(18,2) := null;
v_mto_debito           number(18,2);
v_mto_compra          number(18,2);
v_mto_venta           number(18,2);
v_cot_credito          number(18,4) := null;
v_mto_equ_local        number(18) := null;
v_cod_tra_padre        number(4)  := 303;     -- cod. transaccion padre
v_cotizacion           number(18,2) := null;
v_cod_tra_credito     number(4)  := 196;     -- cod. transaccion hijo credito
v_cod_tra_debito      number(4)  := 503;     -- cod. transaccion hijo debito
v_nro_documento        number(15);
v_tot_realizado        number(18,2);   --
v_nro_referencia       number(15);
v_nro_ope_cambio       number(15);
v_cod_causa            number(3) := null ; -- Codigo de Causal
v_nro_secuencia        number(3) := 0 ;
v_lc_cod_moneda        varchar2(3) ;
--v_lc_mon_credito        varchar2(3) ;
r_gtran                pas_snp.rg_msj;
-- Variables de Salida
v_detalles             clob := null ;
v_can_detalle          number(3);
-- para control de limites
v_res_limite      varchar2(2);
v_fec_snp_horario ge_snp_horarios.fecha%type;
cursor Entidad  is
   Select g.tipo, g.cod_swift, g.participante
   from gv_snp_participantes g
   where g.cod_persona <> fug_obt_per_entidad
   and g.ind_hab_pte_hb = 'S'
   --  and rownum < 25
   order by 1, 3, 2 ;

cursor Documento is
   Select a.cod_tip_documento, a.abreviatura
   from ba_tip_documentos a
   where a.estado = 'A'
     and a.cod_tip_documento in (1, 2,3,5, 6, 43)  -- Solicitado por Edward V.
   order by 1, 2 ;

begin
   if nvl(p_modo,'X') = 'A' then
      v_modo                := p_modo ;
      v_nro_referencia      := p_nro_referencia ;
      v_nro_cta_debito      := p_nro_cta_deb ;
      v_mto_debito          := p_mto_debito ;
      v_cot_debito          := p_cot_debito ;
      v_cta_pte_solicitante := p_nro_cta_cre ;
      v_mto_credito         := p_mto_credito ;
      v_cot_credito         := p_cot_credito ;
      v_cod_mon_credito     := p_cod_mon_cre ;
      v_fec_operacion       := p_fec_operacion ;
       -- Valida la cuenta debito si puede realizar la operación
       pr_val_cta_debito( v_nro_cta_debito,
                          v_cod_tra_padre,
                          v_mto_debito,
                          v_cod_mon_debito,
                          v_cod_mod_debito,
                          v_cod_mad_debito,
                          v_cod_ofi_debito,
                          v_cta_for_debito,
                          v_nom_cta_debito);
   else
      -- 1. valido la clave del cliente
      pr_val_clave(p_parametros);
      
      if v_cod_respuesta = paw_bce.v_cod_aprobado then
        v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '036');
        if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
           v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
        end if;
      end if;
   end if ;

   if v_cod_respuesta = paw_bce.v_cod_aprobado then
      if v_modo = 'S' then -- Consulta de Entidades Registradas.
         v_can_detalle := 0 ;
         for e in Entidad  loop
            v_can_detalle := v_can_detalle + 1 ;
            v_detalles := v_detalles ||
                          lf_for_char(e.cod_swift, 20) ||
                          lf_for_char(e.participante, 60) ;
         end loop ;
         v_detalles := lf_for_number(v_can_detalle,3)|| v_detalles ;
         return v_detalles ;
      elsif v_modo = 'T' then -- Datos de Tipos de Documentos
         v_can_detalle := 0 ;
         for td in Documento  loop
            v_can_detalle := v_can_detalle + 1 ;
            v_detalles := v_detalles ||
                          lf_for_number(td.cod_tip_documento, 3) ||
                          lf_for_char(td.abreviatura, 4) ;
         end loop ;
         v_detalles := lf_for_number(v_can_detalle,3)|| v_detalles ;
         return v_detalles ;
      elsif v_modo = 'D' then -- Datos de Transferencias anteriores
         v_cod_swift := trim(substr(p_parametros, 67, 20));
         v_nro_cta_credito := trim(substr(p_parametros, 87, 17));
         Begin
            Select snp.nom_beneficiario, snp.dir_beneficiario, snp.nro_doc_beneficiario, snp.cod_tip_doc_beneficiario
               into v_nom_cliente, v_dir_cliente, v_nro_doc_cliente, v_tip_doc_beneficiario
            from (Select gs.nom_beneficiario, gs.dir_beneficiario, gs.nro_doc_beneficiario, gs.cod_tip_doc_beneficiario
                  from ge_snp_transferencias gs
                  where gs.cod_swi_pte_beneficiario = v_cod_swift
                    and gs.nro_cta_beneficiario = v_nro_cta_credito
                    and gs.cod_per_solicitante = nvl(v_cod_per_empresa,v_cod_persona)
                  order by gs.fec_insercion desc) snp
            where rownum = 1 ;
         Exception
            When OTHERS then
               v_cod_respuesta := paw_bce.v_cod_cta_inexistente ;
               return null ;
         End;
         v_detalles := lf_for_char(v_nom_cliente,120)||
                       lf_for_char(nvl(v_dir_cliente,'~'),100)||
                       lf_for_char(nvl(v_nro_doc_cliente,'~'),20)||
                       lf_for_number(v_tip_doc_beneficiario,3);
         return v_detalles ;
      elsif v_modo in ('V', 'C','A') then --
         if(v_modo<>'A') then
           v_nro_cta_debito   := lf_obt_cta_limpia(trim(substr(p_parametros, 67, 17)));
           v_cod_mon_credito  := trim(substr(p_parametros, 84, 3));
           v_mto_credito      := substr(p_parametros, 87, 16) ;
           v_fec_operacion    := to_date(substr(p_parametros, 103, 8),'DD/MM/YYYY');
           v_cargos           := substr(p_parametros, 111, 1) ;
           v_nro_cta_credito  := trim(substr(p_parametros, 112, 20));
           v_cod_swift        := trim(substr(p_parametros, 132, 20));
           v_nro_doc_credito  := trim(substr(p_parametros, 152, 20));
           v_nom_beneficiario := trim(substr(p_parametros, 172, 100));
           v_dir_beneficiario := trim(substr(p_parametros, 272, 100));
           v_nro_contrato     := trim(substr(p_parametros, 372, 7));
           v_concepto         := trim(substr(p_parametros, 379, 100));
           v_nro_ip           := trim(substr(p_parametros, 479, 20));
           v_tip_mensaje      := trim(substr(p_parametros, 499, 1));
           v_tip_doc_beneficiario := trim(substr(p_parametros, 500, 3));
         end if;
        if v_modo='A' then
         select t.nro_cta_solicitante, 
              t.monto,
              t.fec_valor,
              substr(t.tip_cargo,0,1),--traducir
              t.nro_cta_beneficiario,
              t.cod_swi_pte_beneficiario,
              t.nro_doc_beneficiario,--
              t.nom_beneficiario,
              t.concepto,
--              t.tip_mensaje,
              t.cod_tip_doc_beneficiario
              into
              v_nro_cta_debito,
              v_mto_credito,
              v_fec_operacion,
              v_cargos,
              v_nro_cta_credito,
              v_cod_swift,
              v_nro_doc_credito,
              v_nom_beneficiario,
              v_concepto,
             -- v_tip_mensaje,
              v_tip_doc_beneficiario
              from ge_snp_transferencias t 
              where t.nro_referencia=v_nro_referencia;
        end if;/**/
         if v_modo = 'V' and v_tip_mensaje = 'T' and (length(v_nro_cta_credito) <> 16
              or translate(v_nro_cta_credito,'T 0123456789','T') is not null) then
            v_cod_respuesta := paw_bce.v_nro_tar_invalido ;
         end if ;
         v_cod_mon_debito   := FUG_OBT_MON_CTA(v_nro_cta_debito) ;
         -- Inicializa las Variables del PAS_SNP
         pas_snp.pr_ini_variables;
         pas_snp.pr_ini_registros;
         v_cta_pte_sol_bcp     :=  pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad), v_cod_mon_credito);
         v_cta_pte_solicitante :=  pas_snp.fu_obt_cta_bancaria(v_cta_pte_sol_bcp ,'C');
         if pas_snp.fu_obt_cod_error <> 0 then
            v_cod_respuesta := paw_bce.v_cta_int_invalida ;
         end if ;
         -- Verifica por seguridad que no se ingrese una cuenta que no sea del titular
         if lf_val_cta_origen(v_nro_cta_debito,nvl(v_cod_per_empresa,v_cod_persona)) = 'N' then
            -- no es una cuenta del cliente
            v_cod_respuesta := paw_bce.v_cod_cta_invalida;
         end if;
         if nvl(v_mto_credito,0) < 1 then
            v_cod_respuesta := paw_bce.v_cod_mto_invalido;
         end if ;
         if v_cod_respuesta = paw_bce.v_cod_aprobado then
            -- moneda diferentes sin contrato de cambio
            if v_cod_mon_credito <> v_cod_mon_debito then
                -- Verifica que no pueda realizar cambio de monedas en fecha distinta a la fecha actual
               if v_fec_operacion <> v_fec_actual then
                  v_cod_respuesta := paw_bce.v_cod_fec_invalida ;
               end if ;
               if nvl(v_nro_contrato,0) = 0 then
                  Begin
                     lp_con_mon_a_moneda(v_cod_mon_credito,
                                         v_cod_mon_debito,
                                         v_mto_credito,
                                         v_mto_debito,
                                         v_cot_credito,
                                         v_cot_debito,
                                         'S');
                  Exception
                     When OTHERS then
                        v_cod_respuesta := paw_bce.v_cod_otr_error;
                  End;
                  if v_cod_mon_debito <> v_cod_mon_local then
                     v_cotizacion := v_cot_debito;
                  else
                     v_cotizacion := v_cot_credito;
                  end if;
                  if v_mto_credito <= 0 or v_mto_debito <= 0 then
                     v_cod_respuesta := paw_bce.v_cod_mto_invalido;
                  end if ;
               else
                  -- Se verifica el horario de Operaciones de Cambio
                  if to_char(sysdate,'HH24:MI') not between
                     to_char(to_date(fug_obt_pardinamico('HOR_PRE_ESP_INICIO', 7, 71),'HH24:MI'),'HH24:MI')  and
                     to_char(to_date(fug_obt_pardinamico('HOR_PRE_ESP_FIN', 7, 71),'HH24:MI'),'HH24:MI') then
                     v_cod_respuesta := paw_bce.v_hor_ope_invalida;
                  end if ;
                  -- Se verifica el contrato de cambio
                  if v_cod_mon_debito = v_cod_mon_local then
                     v_tip_operacion := 30; -- Venta de Divisas
                  else
                     v_tip_operacion := 16; -- Compra de Divisas
                  end if ;
                  begin
                     Select l.cotizacion, l.mto_equ_local, l.nro_operacion,
                        decode(l.cod_moneda, v_cod_mon_debito, l.monto, l.mto_equ_local) Mto_Debito,
                        decode(l.cod_moneda, v_cod_mon_debito, l.mto_equ_local, l.monto) Mto_Credito,
                        l.cod_moneda
                        into v_cotizacion, v_mto_equ_local, v_nro_ope_cambio, v_mto_debito, v_mto_credito,v_lc_cod_moneda
                     from lc_ope_pendientes l
                     where l.nro_diario = v_nro_contrato
                        and l.liquidado = 'N'
                        and l.ope_homebanking = 'S'
                        and l.cod_tip_operacion = v_tip_operacion
                        and l.nro_documento = FUE_OBT_NRO_DOC_PERSONA(nvl(v_cod_per_empresa,v_cod_persona))
                        and l.fec_operacion = v_fec_actual ;
                        --todo a cotizacion
                       v_cot_credito :=v_cotizacion;
                       v_cot_debito  :=v_cotizacion;
      
                  exception
                     when others then
                        v_cod_respuesta := paw_bce.v_con_cam_invalido;
                  end;
               end if ;
               -- No se puede realizar arbitraje por contrato
               if v_cod_mon_debito <> v_cod_mon_local and  v_cod_mon_credito <> v_cod_mon_local then
                  v_cod_respuesta := paw_bce.v_con_cam_invalido;
               end if ;
               -- Si es una venta la moneda de debito debe ser guaranies y la moneda de credito tiene que ser igual al contrato de cambio
               if v_tip_operacion=30 and not ( v_cod_mon_debito = v_cod_mon_local and v_lc_cod_moneda = v_cod_mon_credito) then
                  v_cod_respuesta := paw_bce.v_con_cam_invalido;
               end if;
               --Si es una compra la moneda de debito tiene que ser la moneda del contrato y la de credito tiene que ser guaranies
               if v_tip_operacion=16 and not (  v_cod_mon_debito =v_lc_cod_moneda  and  v_cod_mon_local= v_cod_mon_credito) then
                  v_cod_respuesta := paw_bce.v_con_cam_invalido;
               end if;
               
               
            else
               -- Se iguala el monto por que la Moneda Credito y Debito es igual
               v_mto_debito := v_mto_credito ;
               if nvl(v_nro_contrato, 0) > 0 then
                  v_cod_respuesta := paw_bce.v_con_cam_invalido;
               end if ;
            end if ;
         end if ;

         if v_cod_respuesta = paw_bce.v_cod_aprobado then
            -- Valida la cuenta debito si puede realizar la operación
            pr_val_cta_debito( v_nro_cta_debito,
                               v_cod_tra_padre,
                               v_mto_debito,
                               v_cod_mon_debito,
                               v_cod_mod_debito,
                               v_cod_mad_debito,
                               v_cod_ofi_debito,
                               v_cta_for_debito,
                               v_nom_cta_debito);
            -- agregado para control de limites diarios de transacciones (Opcional)
            if v_cod_respuesta = paw_bce.v_cod_aprobado then
               v_res_limite := fu_obt_limite('036',
                                 nvl(v_cod_per_empresa,v_cod_persona),
                                 v_nro_cta_debito,
                                 v_cod_mon_debito,
                                 503,
                                 v_cod_tra_padre,
                                 v_mto_debito,
                                 v_modo);
            end if;

            -- se verifica la clave transaccional y/o token segun informe de fu_obt_limite
            if v_cod_respuesta = paw_bce.v_cod_aprobado and v_modo <> 'V' then
               if v_res_limite IN ('10', '11') and nvl(p_modo,'X') <> 'A' then -- clave transaccional requerida
                  v_cod_respuesta := lf_obt_cla_validar(p_parametros,v_cod_persona,v_cod_per_empresa,505, 'T');
               end if;

               if v_cod_respuesta = paw_bce.v_cod_aprobado then
                  if v_res_limite IN ('01', '11') and nvl(p_modo,'X') <> 'A' then -- token requerido
                     v_cod_respuesta := fu_obt_tok_validar(p_parametros,v_cod_persona,v_cod_per_empresa,537, v_modo);
                  end if;
               end if;
            end if;
         end if;
         -- Valida la fecha ingresada
         if nvl(pas_snp.fu_val_fec_valor(v_fec_operacion),1) <> 0
                or pag_cal.fu_obt_fec_habil(v_fec_operacion,1,1) <> v_fec_operacion then
            v_cod_respuesta := paw_bce.v_fec_invalida ;
         end if ;
         if v_cta_pte_sol_bcp is null then
            v_cod_respuesta := paw_bce.v_cta_int_invalida ;
         else
            r_gtran.nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante(v_cod_swift, v_cod_mon_credito) ;
            if pas_snp.fu_obt_cod_error <> 0 then
               v_cod_respuesta := paw_bce.v_cta_int_invalida ;
            end if ;
            --Se Evalúa que no exista duplicaos
            r_gtran.fec_valor                := v_fec_operacion ;
            r_gtran.cod_msj_swift            := 103;
            r_gtran.nro_cta_solicitante      := v_nro_cta_debito ;
            r_gtran.nro_cta_pte_solicitante  := v_cta_pte_sol_bcp ;
            r_gtran.nro_cta_beneficiario     := v_nro_cta_credito ;
            r_gtran.cod_swi_pte_beneficiario := v_cod_swift ;
            r_gtran.cod_moneda               := v_cod_mon_credito;
            r_gtran.monto                    := v_mto_credito ;
            if pas_snp.fu_ver_mov_duplicados(r_gtran) <> 0 then
               v_cod_respuesta := paw_bce.v_cod_ped_duplicado ;
            end if ;
         end if ;
         if v_modo = 'V' then
            -- Si esta todo correcto arma el mensaje de respuesta
            if v_cod_respuesta = paw_bce.v_cod_aprobado or v_cod_respuesta = '-88' then
               v_detalles := lf_for_date(v_fec_operacion)||
                             lf_for_char(v_nro_cta_debito,17)||
                             lf_for_char(v_nom_cta_debito,100)||
                             lf_for_char(v_cod_mon_debito,3)||
                             lf_for_money(v_mto_debito,16)||
                             lf_for_char(v_nro_cta_credito,20)||
                             lf_for_char(v_nom_beneficiario,100)||
                             lf_for_char(v_cod_swift,20)||
                             lf_for_char(pas_snp.fu_obt_des_participante(v_cod_swift),60)||
                             lf_for_char(v_cod_mon_credito,3)||
                             lf_for_money(v_mto_credito,16)||
                             lf_for_money(v_cotizacion,18) ||
                             lf_for_char(v_res_limite,2) ;
               return v_detalles ;
            end if ;
    
         
         elsif v_modo in ('C','A') then
            if v_cargos = 'O' then
               v_tip_cargos := 'OUR';
            elsif v_cargos = 'B' then
               v_tip_cargos := 'BEN';
            else
               v_tip_cargos := 'SHA';
            end if ;
            if v_cod_respuesta = paw_bce.v_cod_aprobado then
               -- Se graba la operacion como solicitado y pendiente de autorización
               if v_modo='C' then
                 v_nro_referencia              := pas_snp.fu_obt_sig_nro_referencia(v_fec_actual) ;
                                  
               end if;
               r_gtran.nro_referencia        := v_nro_referencia ;
               r_gtran.cod_modulo            := 4 ;
               r_gtran.cod_modalidad         := 455 ;
               r_gtran.cod_oficina           := v_cod_ofi_debito ;
               r_gtran.cod_tip_operacion     := '001' ;
               r_gtran.cod_sub_tip_operacion    := '002' ;
               r_gtran.fec_ingreso           := v_fec_actual ;
               r_gtran.cod_per_solicitante   := nvl(v_cod_per_empresa,v_cod_persona) ;
               r_gtran.nom_solicitante       := fue_obt_nom_persona(nvl(v_cod_per_empresa,v_cod_persona)) ;
               r_gtran.dir_solicitante       := fue_obt_dir_principa(nvl(v_cod_per_empresa,v_cod_persona)) ;
               r_gtran.cod_tip_doc_solicitante  := fue_obt_doc_principal (nvl(v_cod_per_empresa,v_cod_persona)) ;
               r_gtran.nro_doc_solicitante   := fue_obt_nro_doc_persona(nvl(v_cod_per_empresa,v_cod_persona)) ;
               r_gtran.cod_swi_pte_solicitante := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
               r_gtran.nom_beneficiario      := v_nom_beneficiario ;
               r_gtran.dir_beneficiario      := v_dir_beneficiario ;
               r_gtran.cod_tip_doc_beneficiario := v_tip_doc_beneficiario ;
               r_gtran.nro_doc_beneficiario  := v_nro_doc_credito ;
               r_gtran.nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante(v_cod_swift, v_cod_mon_credito) ;
               r_gtran.observacion           := v_concepto ;
               r_gtran.tip_cargo             := v_tip_cargos ;
               r_gtran.ind_valor             := 'S';
               r_gtran.situacion             := 'P' ; -- Pendiente de Envio a BCP
               r_gtran.estado                := 'S' ; -- Solicitado
               r_gtran.prioridad             := 20 ;
               r_gtran.nro_operacion         := v_nro_referencia ;
               r_gtran.tip_mensaje           := 'CRED' ;
               if v_modo='C' then
                   pas_snp.pr_ins_transferencias(r_gtran) ;
                 if nvl(pas_snp.fu_obt_cod_error,1) <> 0 then
                    v_cod_respuesta := paw_bce.v_cod_tra_invalida ;
                 end if ;
               end if;
               -- Se confirma directamente la operacion, porque no requiere autorizacion
               if v_can_aut_requeridas = 0 then
                  v_modo := 'A'; -- CONFIRMACION
                  -- cambio el estado del contrato de cambio
                  if nvl(v_nro_contrato,0) <> 0 then
                     Update lc_ope_pendientes lc
                       set lc.liquidado = 'S',
                            lc.cod_usu_liquidacion = user,
                            lc.fec_liquidacion = sysdate
                     where lc.nro_operacion = v_nro_ope_cambio ;
                  end if ;
               end if ;
            end if ;
         end if;
         -- valido la duplicacion de transferencias
         pr_val_duplicacion(v_nro_cta_debito,
                            v_mto_debito,
                            v_nro_cta_credito,
                            v_cod_tra_padre);
         -- Se genera la grabación pendiente de Autorización
         if v_modo = 'C' and v_cod_respuesta = paw_bce.v_cod_aprobado then -- grabacion en pendiente
            if nvl(v_nro_contrato,0) = 0 then
               v_mto_equ_local := null;
               if v_cod_mon_debito <> v_cod_mon_credito then
                  if v_cod_mon_debito <> v_cod_mon_local then
                     v_mto_equ_local := nvl(v_mto_credito,0);
                  else
                     v_mto_equ_local := nvl(v_mto_debito,0) ;
                  end if ;
               else
                  v_cotizacion     := null;
                  v_mto_equ_local  := null;
               end if;
            else
               -- cambio el estado del contrato de cambio
               Update lc_ope_pendientes lc
                  set lc.liquidado = 'S',
                      lc.cod_usu_liquidacion = user,
                      lc.fec_liquidacion = sysdate
               where lc.nro_operacion = v_nro_ope_cambio ;
            end if ;
            --- inserto el movimiento pendiente de autorizacion
            select s_nro_documento.nextval into v_nro_documento from dual;
            insert into bw_mov_pendientes(
                nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda,
                descripcion, monto, cotizacion, mto_equ_local, nro_cta_contra,
                estado,can_aut_requeridas, can_aut_faltantes, cod_per_ingreso, mto_contra, cot_contra,
                etiqueta, dato, etiqueta2, dato2, referencia)
             values
                (v_nro_documento,nvl(v_cod_per_empresa,v_cod_persona),sysdate,'036',v_nro_cta_debito,v_cod_mon_debito,
                v_concepto, v_mto_debito, v_cot_debito, v_mto_equ_local, v_cta_pte_solicitante,
                'P', v_can_aut_requeridas, v_can_aut_requeridas, v_cod_persona, v_mto_credito, v_cot_credito,
                'Nro.Cta.Crédito/Moneda Cred.',v_nro_cta_credito||'*'||v_cod_mon_credito,
                'Fecha Valor',to_char(v_fec_operacion,'DD/MM/YYYY'), v_nro_referencia);
         end if ;
      end if ;
      
      -- Valida que este abierto el periodo si es de fecha actual
      if v_fec_operacion = v_fec_actual and v_cod_respuesta = paw_bce.v_cod_aprobado then
         pas_snp.pr_ini_variables ;
         v_estado := pas_snp.fu_obt_est_horario(r_gtran.cod_msj_swift,
                                                r_gtran.cod_tip_operacion,
                                                r_gtran.cod_sub_tip_operacion
                                               );
         if v_estado = 'C' then
            if v_modo = 'V' then
               v_cod_respuesta := '-88';
            end if;
            -- obtenemos la hora para ver si no es antes del inicio
            select s.fecha
              into v_fec_snp_horario
              from ge_snp_horarios s
              where s.cod_periodo = 1;
            if v_fec_snp_horario = v_fec_operacion then  
               v_fec_operacion := pag_cal.FU_OBT_FEC_HABIL(v_fec_operacion+1,1,1) ;
            end if;
         elsif  v_estado not in ('C', 'A') then
            v_cod_respuesta := paw_bce.v_fec_invalida ;
         end if ;
      end if ;
      if v_modo = 'A' and v_cod_respuesta = paw_bce.v_cod_aprobado then
         -- Genera el Mensaje Swift
         v_msj_swift := pas_snp.fu_obt_msj_mt103(v_nro_referencia, 'N') ;
         -- Actualiza el Estado y le agrega el Mensaje Swift generado
         update ge_snp_transferencias gt
            set gt.msj_swift = v_msj_swift,
                gt.estado = 'A'
         where gt.nro_referencia = v_nro_referencia
           and gt.cod_msj_swift = 103 ;
         if sql%notfound then
            v_cod_respuesta := paw_bce.v_ref_invalida ;
         end if;
         -- Bloqueo de Saldos
       /*  v_cod_causa := fug_obt_pardinamico('SNP_BLO_CUENTAS') ;
         v_cod_causa := 2;
         if nvl(v_cod_causa,0) <> 0
            and v_cod_respuesta = paw_bce.v_cod_aprobado
            and v_fec_operacion > v_fec_actual then
            BEGIN
               -- Genera el registro de Bloqueo
              /* INSERT INTO GE_bloqueos
                  (NRO_CUENTA, TIPO, NRO_DOCUMENTO, COD_CAUSA, MONTO,
                   FEC_INICIO, HOR_INICIO, OBSERVACION, TIP_BLOQUEO)
               VALUES
                   (v_nro_cta_debito, 'S', v_nro_referencia, v_cod_causa, v_mto_debito,
                    v_fec_actual,v_hor_actual, 'Bloqueo por SNP HB', 'A');
               -- Actualizar el Saldo de la cuenta
               pag_cta.PR_ACT_SAL_CTA(v_nro_cta_debito, v_cod_mad_debito, 'C',
                                      v_fec_actual, v_hor_actual, null, null, v_mto_debito, 'N');
               v_nro_secuencia := v_nro_secuencia + 1 ;
               pag_cta.pr_obt_cuenta(v_nro_cta_debito);
               r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
               r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
               r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina  ;
               r_gmovi.nro_cuenta      := v_nro_cta_debito  ;
               r_gmovi.cod_moneda      := v_cod_mon_debito   ;
               r_gmovi.cod_usuario     := v_cod_usuario;
               r_gmovi.hora            := v_hor_actual;
               r_gmovi.fecha           := v_fec_actual;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.fec_valor       := v_fec_valor;
               r_gmovi.cod_tra_padre   := 307; -- Bloqueo de Saldos
               r_gmovi.cod_mod_padre   := pag_cta.g_ctas.cod_modulo;
               r_gmovi.cod_mad_padre   := pag_cta.g_ctas.cod_modalidad;
               r_gmovi.cod_transaccion := 604;-- Debito x Bloque de Saldos
               r_gmovi.monto           := v_mto_debito;
               r_gmovi.nro_documento   := v_nro_referencia;
               if v_cod_mon_debito <> v_cod_mon_local then
                  r_gmovi.cotizacion      := v_mto_equ_local;
               end if ;
               r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := 'Bloqueo de Saldo por SNP';
               r_gmovi.estado          := 'N';
               r_gmovi.reversado       := 'N';
               r_gmovi.nro_caja        := v_nro_terminal;
               r_gmovi.cod_causa       := v_cod_causa ;
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
               -- Verifica el Estado de la Cuenta
               if pag_cta.G_CTAS.estado = 'N' then
                  pag_cta.PR_SET_VARIABLES(v_cod_usuario, v_fec_actual, 307, 'N', 'N', v_nro_secuencia, 'S', v_cod_ofi_origen, pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad) ;
                  pag_cta.pr_act_estado(v_nro_cta_debito, 'S', v_fec_actual, v_hor_actual, v_nro_referencia, 'S');
               end if ;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cod_respuesta := paw_bce.v_cod_tra_invalida ;
            END;
         else*/
            -- Genera el Movimiento y envia el mensaje a BCP si la fecha es actual y esta activo
            if v_estado = 'A' and v_cod_respuesta = paw_bce.v_cod_aprobado then
               -- se retornará la transacción a ser utilizada para la generación del movimiento.
               pas_snp.pr_obt_par_mensajes( 103,    -- Tipo MT
                                            '001',  -- Tipo de Operación
                                            '002',  -- Sub-Tipo de Operación
                                            'E',    -- Transferencia Enviada
                                            v_cod_mod_padre,
                                            v_cod_mad_padre,
                                            v_cod_tra_credito
                                            --v_cod_tra_padre
                                          );
               if v_cod_mon_debito <> v_cod_mon_local then
                  if v_cod_mon_credito = v_cod_mon_local then
                     v_mto_equ_local := v_mto_credito ;
                  else
                     v_mto_equ_local := null ;
                  end if ;
               end if ;
               pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                                        v_fec_valor,
                                        v_cod_tra_padre, 'N', 'N',
                                        v_nro_secuencia) ;
               -- Registrar movimientos de Debito al CLIENTE
               pag_cta.pr_act_operacion(v_nro_cta_debito ,     -- Nro.Cta.
                                        v_hor_actual,          -- Hora
                                        'D',                   -- Tip.Mov.
                                        v_cod_mon_debito,      -- Cod.Mon.
                                        v_mto_debito,          -- Monto
                                        v_cod_tra_padre,       -- Trx.Padre
                                        v_cod_tra_debito,      -- Trx.Hija
                                        v_nro_referencia,      -- Nro.Doc.
                                        v_cot_debito,          -- Cotizacion
                                        v_cod_ofi_debito,      -- Ofic.Orig.
                                        v_cod_mod_padre,       -- Mod.Pad.Cliente
                                        v_cod_mad_padre,       -- Mad.Pad.Cliente
                                        NULL,                  -- Cod.Tasa
                                        NULL,                  -- Val.Tasa
                                        nvl(v_concepto, 'HB-SNP-Transf.Cta. '||v_cta_pte_solicitante),-- Concepto
                                        'S',                   -- Emit.Aviso
                                        v_nro_secuencia,
                                        v_fec_actual,
                                        null,   -- Cod_Banco
                                        null,   -- Cod_Causa
                                        v_mto_equ_local );
               if nvl(pag_cta.fu_obt_cod_error,1) <> 0 then
                  v_cod_respuesta := paw_bce.v_cod_tra_invalida ;
               else
                  if v_cod_mon_credito <> v_cod_mon_local then
                     if v_cod_mon_debito = v_cod_mon_local then
                        v_mto_equ_local := v_mto_debito ;
                     else
                        v_mto_equ_local := null ;
                     end if ;
                  end if ;
                  v_tip_movimiento := pas_snp.fu_obt_tip_mov_transaccion(v_cod_mod_padre,v_cod_mad_padre,v_cod_tra_credito) ;
                  if nvl(pas_snp.fu_obt_cod_error,1) <> 0 then
                     v_cod_respuesta := paw_bce.v_cod_tra_invalida ;
                  else
                     -- Setea el Tipo de Movimiento del Rubro para SNP
                     pag_cta.pr_set_cod_rubro(pac_che.fu_obt_rub_cta_ban(v_cta_pte_solicitante), v_tip_movimiento);
                     -- Setea la Referencia del Movimiento para SNP
                     pag_cta.pr_set_referencia(v_cod_swift) ;
                     -- Registrar movimientos a la Cta. Interbancaria
                     pag_cta.pr_act_operacion( v_cta_pte_solicitante, -- Nro.Cta.
                                               v_hor_actual,          -- Hora
                                               v_tip_movimiento,      -- Tip.Mov.
                                               v_cod_mon_credito,     -- Cod.Mon.
                                               v_mto_credito,         -- Monto
                                               v_cod_tra_padre,       -- Trx.Padre
                                               v_cod_tra_credito,     -- Trx.Hija
                                               v_nro_referencia,      -- Nro.Doc.
                                               v_cot_credito,         -- Cotizacion
                                               v_cod_ofi_debito,      -- Ofic.Orig.
                                               v_cod_mod_padre,       -- Mod.Pad.Cliente
                                               v_cod_mad_padre,       -- Mad.Pad.Cliente
                                               NULL,                  -- Cod.Tasa
                                               NULL,                  -- Val.Tasa
                                               nvl(v_concepto, 'HB-SNP-Transf.Cta. '||v_nro_cta_debito),-- Concepto
                                               'S',                   -- Emit.Aviso
                                               v_nro_secuencia,
                                               v_fec_actual,
                                               null,   -- Cod_Banco
                                               null,   -- Cod_Causa
                                               v_mto_equ_local );
                     if pag_cta.fu_obt_cod_error = 0 then
                        pas_snp.pr_gen_mov_cargo(r_gtran,
                                                 v_nro_cta_debito,
                                                 v_cta_pte_solicitante,
                                                 v_mto_credito,
                                                 v_hor_actual,
                                                 v_nro_secuencia);
                                                 --'W');
                     end if;
                     if nvl(pag_cta.fu_obt_cod_error,1) <> 0 then
                        v_cod_respuesta := paw_bce.v_cod_tra_invalida ;
                     else
                        BEGIN
                            -- Actualiza la Transferencia
                            update ge_snp_transferencias gt
                              set gt.fecha       = v_fec_actual,
                                  gt.hora        = v_hor_actual,
                                  gt.cod_usuario = v_cod_usuario
                            where gt.nro_referencia = v_nro_referencia
                              and gt.cod_msj_swift = 103 ;

                           if sql%notfound then
                              v_cod_respuesta := paw_bce.v_err_snp ;
                           end if;
                        END;
                     end if ;
                  end if ;
               end if;
           -- end if ;
            -- Si esta todo OK envia la transferencia al Socket
            if v_estado = 'A' and v_cod_respuesta = paw_bce.v_cod_aprobado then
               commit ; -- Commitea antes de intentar enviar al socket
               pas_snp.pr_gen_arc_swift(v_nro_referencia, 'N') ;
              /* if nvl(pas_snp.g_cod_error,0) <> 0 then
                  v_cod_respuesta := paw_bce.v_err_comunicacion ;
               end if ;
               */
            end if ;
         end if ;
      end if ;
   end if ;

   if nvl(p_modo,'X') <> 'A' then
      -- registro del movimiento
      lp_reg_operacion(v_nro_cta_debito,-- \*p_nro_cuenta*\,
                       v_cod_mon_debito,-- \*p_cod_moneda *\,
                       v_mto_debito,-- \*p_monto*\,
                       null,-- \*p_nro_cta_contra*\,
                       null,
                       'Entidad_Destino',
                       v_cod_swift,
                       'Cta. Destino',
                       v_nro_cta_credito,
                       v_concepto,
                       v_nro_ip,
                       v_modo||'-'||v_can_aut_requeridas||'-'||v_nro_referencia,
                       'Nro. referencia',
                       to_char(v_nro_referencia));
      -- Responde para el modo 'C'
      return lf_for_number(v_can_aut_requeridas,3)|| lf_for_date(v_fec_operacion)||
                       lf_for_char(v_nro_cta_debito,17)||
                       lf_for_char(v_nom_cta_debito,100)||
                       lf_for_char(v_cod_mon_debito,3)||
                       lf_for_money(v_mto_debito,16)||
                       lf_for_char(v_nro_cta_credito,20)||
                       lf_for_char(v_nom_beneficiario,100)||
                       lf_for_char(v_cod_swift,20)||
                       lf_for_char(pas_snp.fu_obt_des_participante(v_cod_swift),60)||
                       lf_for_char(v_cod_mon_credito,3)||
                       lf_for_money(v_mto_credito,16)||
                       lf_for_money(v_cotizacion,18)||
                       v_nro_referencia;
   end if ;
   -- registro del movimiento
   lp_reg_operacion(v_nro_cta_debito /*p_nro_cuenta*/,
                    v_cod_mon_debito /*p_cod_moneda */,
                    v_mto_debito /*p_monto*/,
                    null /*p_nro_cta_contra*/,
                    null,
                    'Entidad_Destino',
                    v_cod_swift,
                   'Cta. Destino',
                    v_nro_cta_credito,
                    v_concepto,
                    v_nro_ip,
                    v_modo||'-'||v_can_aut_requeridas,
                    'Nro. referencia',
                    to_char(v_nro_referencia));
   -- no se responde nada, solo se debe setear el v_cod_respuesta
   return null;
end;
-- fin de 036- Confirmacion de transferencias Interbancarias

-- OMM 13/12/2011 -- 037  Consulta de Transferencia Interbancaria
function fu_pro_operacion_037(p_parametros in varchar2)
  return clob is
-- Variables Recibidas
v_tip_mensaje        varchar2(1) := substr(p_parametros, 66, 1); -- C(Cabecera), D(Detalle)
v_nro_referencia     varchar2(20);
v_fec_desde          date;
v_fec_hasta          date;
v_nro_pagina         number(2);   -- nro de pagina
-- Variables Internas
v_cod_cliente        varchar2(10) ;
v_fin                varchar2(1) := 'S'; -- Indica si es final de paguina
v_reg_inicial        number(10);
v_reg_final          number(10);
v_can_pagina         number(5) := 20;   -- transferencias por pagina
v_can_transferencias number(8) := 0;
-- Variables de Salida
v_can_detalles       number(3) := 0;    -- cantidad de detalle
v_detalles           clob := null;      -- datos de las cuentas

cursor cabecera (p_cod_persona in varchar2, p_fec_desde in date, p_fec_hasta in date) is
   Select 'E' Tipo, a.nro_referencia, a.nro_sec_lote, a.fec_valor,
          a.nro_cta_beneficiario, a.nom_beneficiario,
          pas_snp.fu_obt_des_participante(a.cod_swi_pte_beneficiario) Entidad,
          FUE_OBT_DES_MONEDA(a.cod_moneda) moneda, a.monto,
          FUE_OBT_DES_REFCODES('SITUACION',a.situacion) Situacion,
          FUE_OBT_DES_REFCODES('EST_MSJ_SNP',a.estado) Estado,a.fec_insercion, a.cod_moneda
     from ge_snp_transferencias a
    where 
      ( 
        (a.cod_per_solicitante = p_cod_persona) or
        (a.cod_per_solicitante in (select c.cod_persona 
                                     from ge_cta_clientes  c
                                    where c.nro_cuenta=a.nro_cta_solicitante)
          and p_cod_persona in (select c.cod_persona 
                                  from ge_cta_clientes  c
                                 where c.nro_cuenta=a.nro_cta_solicitante)
        )
      )
      and a.nro_cta_beneficiario is not null
      and a.fec_valor between p_fec_desde and p_fec_hasta
      and a.cod_swi_pte_solicitante = pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad)
    union
   Select 'R' Tipo, a.nro_referencia, a.nro_sec_lote, a.fec_valor,
          a.nro_cta_solicitante, a.nom_solicitante,
          pas_snp.fu_obt_des_participante(a.cod_swi_pte_solicitante) Entidad,
          FUE_OBT_DES_MONEDA(a.cod_moneda) moneda, a.monto,
          FUE_OBT_DES_REFCODES('SITUACION',a.situacion) Situacion,
          FUE_OBT_DES_REFCODES('EST_MSJ_SNP',a.estado) Estado,a.fec_insercion, a.cod_moneda
     from ge_snp_transferencias a
    where
     (
       (a.cod_per_beneficiario= p_cod_persona) or
       (a.cod_per_beneficiario in (select c.cod_persona 
                                     from ge_cta_clientes  c
                                    where c.nro_cuenta=a.nro_cta_beneficiario)
         and p_cod_persona in (select c.cod_persona 
                                 from ge_cta_clientes  c
                                where c.nro_cuenta=a.nro_cta_beneficiario)
       ) 
     )
     and a.nro_cta_beneficiario is not null
     and a.fec_valor between p_fec_desde and p_fec_hasta
     and a.cod_swi_pte_beneficiario = pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad)
     and a.nro_ref_externa is not null
  order by fec_valor desc;

cursor detalle(p_nro_ref in number)  is
   Select decode(a.nro_ref_externa, null, 'E', 'R') Tipo, a.nro_referencia,
      a.fec_valor, a.nro_cta_beneficiario nro_cta_credito,
      a.nro_cta_solicitante nro_cta_debito, 
      decode(a.nro_ref_externa, null, a.nom_beneficiario, a.nom_solicitante) nom_beneficiario, --a.nom_beneficiario,
      pas_snp.fu_obt_des_participante(decode(a.nro_ref_externa, null, a.cod_swi_pte_beneficiario, a.cod_swi_pte_solicitante)) Entidad,
      decode(a.nro_ref_externa, null, a.cod_swi_pte_beneficiario, a.cod_swi_pte_solicitante) Cod_swift,
      FUE_OBT_DES_MONEDA(a.cod_moneda) moneda, a.monto,
      FUE_OBT_DES_REFCODES('SITUACION',a.situacion) Situacion,
      FUE_OBT_DES_REFCODES('EST_MSJ_SNP',a.estado) Estado, a.msj_swift
   from ge_snp_transferencias a
   where a.nro_referencia = p_nro_ref ;

Begin
   -- 1. valido la clave del cliente
   pr_val_clave(p_parametros);
   -- 2. busco los datos del Cliente
   v_cod_cliente := nvl(v_cod_per_empresa,v_cod_persona) ;
   if v_cod_respuesta = paw_bce.v_cod_aprobado then
      if v_tip_mensaje = 'C' then
         v_fec_desde := to_date(substr(p_parametros, 67, 8),'DD/MM/YYYY');
         v_fec_hasta := to_date(substr(p_parametros, 75, 8),'DD/MM/YYYY');
         v_nro_pagina  := nvl(substr(p_parametros, 83, 2),1) ;
         v_reg_inicial := (v_nro_pagina * v_can_pagina) - (v_can_pagina - 1);
         v_reg_final   := (v_nro_pagina * v_can_pagina);
         v_can_detalles := 0;
         if v_fec_hasta = v_fec_actual then
            v_fec_hasta := pag_cal.fu_obt_fec_fin_ret( v_fec_hasta, NULL, nvl( fug_obt_pardinamico ( 'SNP_RAN_DIA_FEC_VALOR'),0 )) ;
         end if ;
         for cab in cabecera(v_cod_cliente, v_fec_desde, v_fec_hasta)  loop
            v_can_transferencias := v_can_transferencias + 1;
            if v_can_transferencias between v_reg_inicial and v_reg_final then
               v_can_detalles := v_can_detalles + 1;
               v_detalles :=  v_detalles ||
                              lf_for_char(cab.tipo,1)||
                              lf_for_char(cab.nro_referencia,15)||
                              lf_for_char(substr(cab.nro_sec_lote,-5),20)||
                              lf_for_char(TO_CHAR(cab.fec_valor,'DDMMYYYY'),8)|| 
                              lf_for_char(cab.nro_cta_beneficiario,35)||
                              lf_for_char(cab.nom_beneficiario,120)||
                              lf_for_char(cab.entidad,60)||
                              lf_for_char(cab.cod_moneda,3)||
                              lf_for_money(cab.monto,18)||
                              lf_for_char(cab.situacion,30)||
                              lf_for_char(cab.estado,30)||
                              lf_for_char(TO_CHAR(cab.fec_insercion,'HH24:MI'),5);

                if v_can_transferencias >= v_reg_final then
                   v_fin := 'N';
                   exit;
                end if;
             end if ;
         end loop;
         v_detalles := lf_for_number(v_can_detalles,3)||v_fin||v_detalles ;
      else
         v_nro_referencia := to_number(substr(p_parametros, 83, 20));
         for det in detalle(v_nro_referencia)  loop
            v_detalles :=  v_detalles ||
                           lf_for_char(det.tipo,1)||
                           lf_for_char(det.nro_referencia,20)||
                           lf_for_char(det.fec_valor,8)||
                           lf_for_char(det.nro_cta_credito,35)||
                           lf_for_char(det.nro_cta_debito,35)||
                           lf_for_char(det.nom_beneficiario,80)||
                           lf_for_char(det.entidad,60)||
                           lf_for_char(det.cod_swift,20)||
                           lf_for_char(det.moneda,30)||
                           lf_for_money(det.monto,17)||
                           lf_for_char(det.situacion,30)||
                           lf_for_char(det.estado,30)||
                           lf_for_char(nvl(REPLACE(REPLACE(det.msj_swift,chr(10),' '), chr(13), ''),'~'),2000) ;
         end loop;
      end if ;
      if v_cod_respuesta = paw_bce.v_cod_aprobado then
         -- registro del movimiento
         lp_reg_operacion(null /*p_nro_cuenta*/,
                          null /*p_cod_moneda */,
                          null /*p_monto*/,
                          null /*p_nro_cta_contra*/,
                          null /*p_cantidad*/,
                          'Tipo Consulta' /*p_etiqueta*/,
                           v_tip_mensaje/*p_dato*/,
                           'Cantidad Msj',
                           v_can_detalles );
         -- todo ok, se arma el mensaje de respuesta
         return v_detalles;
      end if ;
   else
      -- registro del movimiento
      lp_reg_operacion(null /*p_nro_cuenta*/,
                       null /*p_cod_moneda */,
                       null /*p_monto*/,
                       null /*p_nro_cta_contra*/,
                       null /*p_cantidad*/,
                       'Tipo Consulta' /*p_etiqueta*/,
                        v_tip_mensaje/*p_dato*/ );
      return null;  -- nada
   end if;
exception
   when others then
      raise_application_error(-20005,sqlerrm);
end;
-- fin de la 037 - Consulta de Transferencia Interbancaria

-- 038 - OMM - Cancelación de Transferencia Interbancaria SNP
function fu_pro_operacion_038(p_parametros      in varchar2,
                              p_modo            in varchar2 default null,
                              p_nro_referencia  in number   default null)
  return clob is
--Variables Recibidas
v_modo                 varchar2(1) := substr(p_parametros, 66, 1); -- C(Cabecera), D(Detalle)
v_nro_referencia       number(20) ;
v_nro_documento        number(15);
--Variables Locales
v_nro_cta_debito       varchar2(20);
v_nro_cta_credito      varchar2(20);
v_cod_moneda           varchar2(3) ;
v_monto                number(18,2);
v_fec_operacion        date;
-- Variables de Salida
v_detalles             clob := null;
v_can_detalle          number(3);

cursor cabecera (p_cod_persona in varchar2) is
   Select a.nro_referencia, a.nro_sec_lote, a.fec_valor,
      a.nro_cta_beneficiario, a.nom_beneficiario,
      pas_snp.fu_obt_des_participante(a.cod_swi_pte_beneficiario) Entidad,
      FUE_OBT_DES_MONEDA(a.cod_moneda) moneda, a.monto, a.cod_moneda
   from ge_snp_transferencias a
   where a.cod_per_solicitante = p_cod_persona
      and a.nro_cta_beneficiario is not null
      and a.fec_valor >= v_fec_actual
      and a.situacion = 'P' -- Solo los que estan Pendiente de Envío.
      and a.estado not in ('C', 'E')
      and a.fecha is null -- Solo los que no tienen movimiento asociado (Fecha Futura)
      and a.cod_swi_pte_solicitante = pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad)
      -- Para no mostrar las transferencias solicitadas para cancelar - Empresas
      and not exists ( Select 1 from bw_mov_pendientes b
                       where b.cod_per_principal = p_cod_persona
                         and trunc(b.fec_hora) = trunc(sysdate)
                         and b.estado = 'P'
                         and b.cod_tip_mensaje = '038'
                         and b.referencia = a.nro_referencia)
  order by fec_valor desc;

begin
   if nvl(p_modo,'X') = 'A' then
      v_modo                := 'E' ;
      v_nro_referencia      := p_nro_referencia ;
   else
      -- 1. valido la clave del cliente
      v_nro_referencia      := substr(p_parametros, 67, 20) ;
      pr_val_clave(p_parametros);
      
      if v_cod_respuesta = paw_bce.v_cod_aprobado then
        v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '038');
        if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
           v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
        end if;
      end if;
   end if ;

   if v_cod_respuesta = paw_bce.v_cod_aprobado then
      if v_modo = 'C' then -- Consulta de Entidades Registradas.
         v_can_detalle := 0 ;
         for cb in cabecera(nvl(v_cod_per_empresa,v_cod_persona))  loop
            v_can_detalle := v_can_detalle + 1 ;
            v_detalles := v_detalles ||
                          lf_for_char(cb.nro_referencia,15)||
                          lf_for_number(cb.nro_sec_lote,20)||
                          lf_for_date(cb.fec_valor)||
                          lf_for_char(cb.nro_cta_beneficiario,35)||
                          lf_for_char(cb.nom_beneficiario,120)||
                          lf_for_char(cb.entidad,60)||
                          lf_for_char(cb.cod_moneda,3)||
                          lf_for_money(cb.monto,18);
         end loop ;
         v_detalles := lf_for_number(v_can_detalle,3)|| v_detalles ;
      elsif v_modo = 'D' then -- Datos de Transferencias anteriores
         v_detalles := fuw_imp_comprobante(v_nro_referencia,v_fec_actual, v_nro_referencia, null, 'I', null);
      elsif v_modo = 'E' then -- Cancelación
         if nvl(p_modo,'X') = 'A' or v_can_aut_requeridas = 0 then
            pas_snp.pr_obt_mensaje(v_nro_referencia, 'N') ;
            pas_snp.g_msj.estado := 'C' ;
            PAS_SNP.PR_SET_TRANSFERENCIAS(pas_snp.fu_obt_reg_transferencias) ;
            if pas_snp.g_cod_error <> 0 then
               v_cod_respuesta := paw_bce.v_cod_dat_invalido ;
            end if ;
         else
            Begin
               Select t.nro_cta_solicitante, t.monto, t.cod_moneda, t.nro_cta_beneficiario, t.fec_valor
                 into v_nro_cta_debito, v_monto, v_cod_moneda, v_nro_cta_credito, v_fec_operacion
               from ge_snp_transferencias t
               where t.nro_referencia = v_nro_referencia ;
            exception
               when others then
                  v_cod_respuesta := paw_bce.v_cod_cta_sin_mov ;
            end ;
            -- Se inserta el movimiento pendiente de autorizacion si encontro el registro
            if  v_cod_respuesta = paw_bce.v_cod_aprobado then
               select s_nro_documento.nextval into v_nro_documento from dual;
               insert into bw_mov_pendientes(
                  nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta,
                  descripcion, estado, can_aut_requeridas, can_aut_faltantes,
                  cod_per_ingreso, monto, etiqueta, dato,
                  etiqueta2, dato2, referencia, cod_moneda)
               values
                  (v_nro_documento,nvl(v_cod_per_empresa,v_cod_persona),sysdate,'038', v_nro_cta_debito,
                   'Cancelación de Operación', 'P', v_can_aut_requeridas, v_can_aut_requeridas,
                   v_cod_persona, v_monto, 'Nro.Cta.Crédito/Moneda', v_nro_cta_credito||' / '||v_cod_moneda,
                   'Fecha Valor',v_fec_operacion, v_nro_referencia, v_cod_moneda);
            end if ;
            v_detalles := lf_for_number(v_can_aut_requeridas,5) ;
         end if;
      end if ;
    end if ;
    -- registro del movimiento
    lp_reg_operacion( null /*p_nro_cuenta*/,
                      null /*p_cod_moneda */,
                      null /*p_monto*/,
                      null /*p_nro_cta_contra*/,
                      null /*p_cantidad*/,
                      'Cancelacion' /*p_etiqueta*/,
                      v_modo/*p_dato*/,
                      'Nro de Referencia',
                      v_nro_referencia);
    return v_detalles;
exception
   when others then
      return null ;
end;

  -- 039-validacion o confirmacion de transferencia entre cuentas de diferentes titulares
  function fu_pro_operacion_039(p_parametros      in varchar2,
                                p_nro_cta_debito  in varchar2 default null,
                                p_monto           in number   default null,
                                p_nro_cta_credito in varchar2 default null,
                                p_modo            in varchar2 default null,
                                p_cotizacion      in number   default null,
                                p_mto_credito     in number   default null,
                                p_cot_credito     in number   default null,
                                p_nro_doc_credito in varchar2 default null,
                                p_concepto        in varchar2 default null
    )
    return varchar2 is
  -- datos recibidos
  v_nro_cta_debito  varchar2(16);
  v_monto           number(18,2);   -- monto a transferir
  v_nro_cta_credito varchar2(17);   -- cuenta de credito
  v_modo            varchar2(1);    -- modo V-validacion o C-confirmacion
  -- variables
  v_cta_for_debito  varchar2(17);  -- cuenta formateada
  v_cod_mon_debito  varchar2(3);   -- moneda de la cuenta
  v_est_cta_debito  varchar2(1);   -- estado de la cuenta
  v_cod_mod_debito  number(4);     -- modulo de la cuenta
  v_cod_mad_debito  number(4);     -- modalidad de la cuenta
  v_cod_ofi_debito  number(4);     -- oficina de la cuenta
  v_nvo_est_debito  varchar2(1) := null; -- cambio de estado de cuenta
  v_cot_debito      number(18,2) := null;
  v_nom_cta_debito  varchar2(100);

  v_cod_mon_credito  varchar2(3);   -- moneda de la cuenta
  v_cta_for_credito  varchar2(17);  -- cuenta formateada
  v_est_cta_credito  varchar2(1);   -- estado de la cuenta
  v_cod_mod_credito  number(4);     -- modulo de la cuenta
  v_cod_mad_credito  number(4);     -- modalidad de la cuenta
  v_cod_ofi_credito  number(4);     -- oficina de la cuenta
  v_nvo_est_credito  varchar2(1) := null; -- cambio de estado de cuenta
  v_sal_dis_credito  number(18,2);
  v_mto_credito      number(18,2) := v_monto;
  v_cot_credito      number(18,4) := null;
  v_nom_cta_credito  varchar2(100);
  v_mto_equ_local    number(18) := null;

  v_cod_tra_padre   number(4)  := 388;     -- cod. transaccion padre
  v_procesa         varchar2(1) := 'N';    -- indica si se puede o no procesar
  v_cotizacion      number(18,2) := null;
  v_nro_documento   number(15);
  v_nro_doc_credito varchar2(20) := null;  -- nro de documento del acreditado
  v_mto_limite      number(18,2);   -- monto limite para transferencias
  v_tot_realizado   number(18,2);   --
  v_concepto        varchar2(100);
  -- para control de límites
  v_res_limite      varchar2(2);
  v_ini_lim_param   number;
  v_ini_cla_tran    number;
  v_ini_token       number;
  v_res_notificacion number(3);
  --

  begin
    -- 0. inicializo la secuencia
    v_nro_secuencia := 0;
    if nvl(p_modo,'x') = 'A' then
       -- viene de confirmacion de una autorización
       v_nro_cta_debito  := p_nro_cta_debito;
       v_monto           := p_monto;
       v_nro_cta_credito := p_nro_cta_credito;
       v_modo            := p_modo;
       v_cotizacion      := p_cotizacion;
       v_mto_credito     := p_mto_credito;
       v_cot_debito      := p_cotizacion;
       v_cot_credito     := p_cot_credito;
       v_nro_doc_credito := p_nro_doc_credito;
       v_concepto        := p_concepto;
    else
       v_nro_cta_debito  := lf_obt_cta_limpia(trim(substr(p_parametros,66,16)));
       v_monto           := nvl(to_number(replace(trim(substr(p_parametros,82,16)),',','.')),0);   -- monto a transferir
       v_nro_cta_credito := lf_obt_cta_limpia(trim(substr(p_parametros,98,16)));   -- cuenta de crédito
       v_modo            := substr(p_parametros,114,1);    -- modo V-validación o C-confirmación
       if length(p_parametros) > 115 then
          -- nro de documento del acreditado
          v_nro_doc_credito := trim(replace(replace(substr(p_parametros,115,16),chr(13),''),chr(10),''));
       end if;
       if length(p_parametros) > 131 then
          v_concepto := trim(replace(replace(substr(substr(p_parametros,131),1,35),chr(13),''),chr(10),''));
          v_concepto := lf_obt_alfanumerico(v_concepto, 35);
       end if;
       -- 1. valido la clave del cliente
       pr_val_clave(p_parametros);
       if v_modo = 'C' and v_can_aut_requeridas = 0 then
          -- se confirma directamente la operación, porque no requiere autorización
          v_modo := 'A'; -- CONFIRMACION
       end if;
    end if;
    -- Verifico si el cliente con su perfil tendrá acceso a realizar la transaccion
    if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(p_modo,'x') <> 'A' then
       v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '039');
       if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
          v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
       end if;
    end if;    
    -- 2. busco los datos de la cuentas
    if v_cod_respuesta = paw_bce.v_cod_aprobado then
        -- verifico cuenta de débito
        if v_nro_cta_debito = v_nro_cta_credito then
           --raise_application_error(-20005,' Cta debito '||v_nro_cta_debito||' Cta Credito '||v_nro_cta_credito);
           v_cod_respuesta := paw_bce.v_cod_tra_invalida;
        else
          pr_val_cta_debito( v_nro_cta_debito,
                             v_cod_tra_padre,
                             v_monto,
                             v_cod_mon_debito,
                             v_cod_mod_debito,
                             v_cod_mad_debito,
                             v_cod_ofi_debito,
                             v_cta_for_debito,
                             v_nom_cta_debito);
          if v_modo = 'C' and v_can_aut_requeridas = 0 then
            -- se confirma directamente la operación, porque no requiere autorización
            v_modo := 'A'; -- CONFIRMACION
          end if;
          if v_cod_respuesta = paw_bce.v_cod_aprobado then
             if lf_val_cta_origen(v_nro_cta_debito,nvl(v_cod_per_empresa,v_cod_persona)) = 'N' then
                -- no es una cuenta del cliente
                v_cod_respuesta := paw_bce.v_cod_cta_invalida;
             end if;
          end if;
          if v_cod_respuesta = paw_bce.v_cod_aprobado then
             if lf_val_cta_origen(v_nro_cta_credito,nvl(v_cod_per_empresa,v_cod_persona)) = 'S' then
                -- es una cuenta del cliente en una transferencia a terceros
                if fu_es_juridica(v_nro_cta_credito) = 'N' then -- debe poder transferir a cuenta juridica donde es firmante
                   v_cod_respuesta := paw_bce.v_cod_cta_invalida;
                end if;
             end if;
          end if;         
          --           
        end if;
       if v_cod_respuesta = paw_bce.v_cod_aprobado then
          -- cuenta de credito
          begin
              select a.cod_moneda, a.estado, cod_modalidad,
                     cod_modulo, cod_oficina,
                     fug_cta_formateada(cod_modulo, cod_modalidad, cod_oficina,nro_cuenta, cod_moneda) cta_formateada,
                     denominacion
                into v_cod_mon_credito,
                     v_est_cta_credito, v_cod_mad_credito,
                     v_cod_mod_credito, v_cod_ofi_credito,
                     v_cta_for_credito, v_nom_cta_credito
                from ge_cuentas a
               where a.nro_cuenta = v_nro_cta_credito; -- contiene el nro de cuenta
               -- credito
               if v_cod_mon_credito <> v_cod_mon_debito  then
                  -- moneda diferentes
                    -- AP 2764 ---------------------------------------------------------------------------------
                    IF v_cod_respuesta = paw_bce.v_cod_aprobado THEN
                       IF lf_val_cta_origen(v_nro_cta_credito, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' THEN
                          -- no es una cuenta del cliente
                          v_cod_respuesta := paw_bce.v_cod_cta_invalida;
                       END IF;
                    END IF;
                    --------------------------------------------------------------------------------------------  
                  -- cod_respuesta := paw_bce.v_cod_tra_invalida;
                  if nvl(p_modo,'x') <> 'A' then
                      Begin
                      lp_con_mon_a_moneda(v_cod_mon_debito,
                                          v_cod_mon_credito,
                                          v_monto,
                                          v_mto_credito,
                                          v_cot_debito,
                                          v_cot_credito);
                      Exception
                         When OTHERS then
                              v_cod_respuesta := paw_bce.v_cod_otr_error;
                      End;
                  end if;
                  if v_cod_mon_debito <> v_cod_mon_local then
                     v_cotizacion := v_cot_debito;
                  else
                     v_cotizacion := v_cot_credito;
                  end if;
               else
                  v_mto_credito := v_monto;
               end if;
               if v_mto_credito <= 0 then
                  v_cod_respuesta := paw_bce.v_cod_mto_invalido;
               elsif v_cod_mad_credito not in (31,41) then
                  v_cod_respuesta := paw_bce.v_cod_cta_invalida;
               elsif v_est_cta_credito not in ('A','I','N','S') then
                  v_cod_respuesta := paw_bce.v_cod_cta_invalida;
               elsif pag_cta.fu_ver_tra_prohibida(v_nro_cta_credito,v_cod_tra_padre, 9, 91) = 'S' then
                  v_cod_respuesta := paw_bce.v_cod_tra_prohibida;
               else
                  pag_cta.pr_ver_operacion(v_nro_cta_credito,v_cod_tra_padre,9,91,'C',v_cod_mon_credito, v_mto_credito, v_cod_ofi_origen,
                                           v_cod_mod_credito, v_cod_mad_credito, v_nvo_est_credito, v_sal_dis_credito,
                                           v_procesa,602);
                  if v_procesa = 'N' then
                     -- no se puede debitar
                     v_cod_respuesta := paw_bce.v_cod_cta_invalida;
                  elsif v_nro_doc_credito is not null and lf_cta_valida(v_nro_cta_credito, v_nro_doc_credito)='N' then
                     -- no se puede acreditar a la cuenta de este nro de documento
                     if v_cod_respuesta = paw_bce.v_cod_aprobado then
                        v_cod_respuesta := paw_bce.v_cod_cta_invalida;
                     end if;
                  end if;
               end if;
               -- valido la duplicación de transferencias pendientes
               if v_cod_respuesta = paw_bce.v_cod_aprobado then
                 if fu_ver_mov_pendiente(v_cod_per_empresa, v_nro_cta_debito, v_nro_cta_credito, v_monto, '039') = 'S' then
                   v_cod_respuesta := paw_bce.v_cod_pag_pendiente;
                 end if;
               end if;
               -- valido la duplicación de transferencias
               if v_cod_respuesta = paw_bce.v_cod_aprobado then
                 if fu_ver_transaccion(503, v_cod_tra_padre, v_nro_cta_debito, v_monto) = 'S' then
                   v_cod_respuesta := v_cod_mov_ya_ingresado;
                 end if;
               end if;
          exception
              when no_data_found then
                 v_cod_respuesta  := paw_bce.v_cod_cta_invalida;
              when too_many_rows then
                 v_cod_respuesta  := paw_bce.v_cod_cta_duplicada;
              when others then
                 v_cod_respuesta  := paw_bce.v_cod_cta_invalida;
          end;
          -- 26/04/2012 : Verifico que la cta de débito tenga límite para la operación
          -- se agrega monitoreo de límite global de transferencias a terceros
          if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(p_modo, 'x') <> 'A' then
             if v_modo IN ('C', 'V', 'A') then
               v_res_limite := fu_obt_limite('039', 
                            nvl(v_cod_per_empresa,v_cod_persona), 
                            v_nro_cta_debito, 
                            v_cod_mon_debito, 
                            503, 
                            v_cod_tra_padre,
                            v_monto,
                            v_modo );
            end if;
          end if; 
      --Si es confirmación debe tener la clave de transacción            
      if v_modo = 'A' or v_modo = 'C' then
        IF v_cod_respuesta = paw_bce.v_cod_aprobado and lf_val_cta_origen(v_nro_cta_credito, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' THEN
           -- no es una cuenta del cliente tiene que tener codigo de transaccion
           /* CR: no hace falta que controle aqui la clave, ya controla desde la funcion autorizadora
           if v_modo = 'A' and v_can_aut_requeridas>0 then
              v_cod_respuesta := lf_obt_cla_validar(p_parametros,v_cod_persona,v_cod_per_empresa,132);
           else */
           if nvl(p_modo, 'x') <> 'A' then 
              -- obtengo lo que recibí del cgi sobre límites
              v_ini_lim_param := 166;
              v_ini_cla_tran  := v_ini_lim_param + 2;
              v_ini_token     := v_ini_cla_tran + 32;
                            
              -- 26/04/2012 : límite de operaciones
              if v_res_limite IN ('10', '11')  then -- clave transaccional requerida
                 v_cod_respuesta := lf_obt_cla_validar(p_parametros,v_cod_persona,v_cod_per_empresa,v_ini_cla_tran,'T');
              end if;
                
              if v_cod_respuesta = paw_bce.v_cod_aprobado then
                 if v_res_limite IN ('01', '11') then -- token requerido
                    v_cod_respuesta := fu_obt_tok_validar(p_parametros,v_cod_persona,v_cod_per_empresa,v_ini_token, v_modo);
                 end if;
              end if;  
              -- : límite operaciones
           end if;          
           v_concepto:=substr('Transf. a '||v_nro_cta_credito|| ' desde '||v_nro_cta_debito ||' '||trim(v_concepto),0,100);
      END IF;
      --Fin de clave de transacción
      end if;        
          if v_cod_respuesta = paw_bce.v_cod_aprobado then
             -- no hay problemas hasta aquí
             if v_modo = 'V' then -- validación
                return lpad(ltrim(lf_for_money(v_cotizacion,16)),16,'0')||
                       lf_for_char(v_cta_for_debito,17)||
                       lf_for_char(v_nom_cta_debito,50)||
                       lf_for_char(rpad(v_cod_mon_debito,3,'.'),3)||
                       lf_for_money(v_monto,16)||
                       lf_for_char(v_cta_for_credito,17)||
                       lf_for_char(v_nom_cta_credito,50)||
                       lf_for_char(rpad(v_cod_mon_credito,3,'.'),3)||
                       lf_for_money(v_mto_credito,16)||
                       -- para límite de operaciones
                       lf_for_char(v_res_limite, 2);
                       --
             elsif v_modo = 'C' then -- grabación en pendiente
                if v_cod_mon_debito <> v_cod_mon_local and
                   v_cod_mon_debito <> v_cod_mon_credito and
                   v_cod_mon_credito = v_cod_mon_local then
                   v_mto_equ_local := v_mto_credito;
                else
                   v_mto_equ_local  := null;
                end if;
                --- inserto el movimiento pendiente de autorización
                select s_nro_documento.nextval into v_nro_documento from dual;
                insert into bw_mov_pendientes
                  (nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda,
                   descripcion, monto, cotizacion, mto_equ_local, nro_cta_contra,
                   estado,can_aut_requeridas, can_aut_faltantes, cod_per_ingreso, mto_contra, cot_contra,
                   etiqueta, dato, etiqueta2, dato2)
                values
                   (v_nro_documento,nvl(v_cod_per_empresa,v_cod_persona),sysdate,'039',v_nro_cta_debito,v_cod_mon_debito,
                    'Transferencia entre Cuentas',v_monto, v_cot_debito, v_mto_equ_local, v_nro_cta_credito,
                    'P', v_can_aut_requeridas, v_can_aut_requeridas, v_cod_persona, v_mto_credito, v_cot_credito,
                    'Nro.Identificacion',v_nro_doc_credito, 'Concepto',substr(v_concepto,0,50)
                   );
                -- registro del movimiento
                lp_reg_operacion(v_nro_cta_debito /*p_nro_cuenta*/,
                                 v_cod_mon_debito /*p_cod_moneda */,
                                 v_monto /*p_monto*/,
                                 v_nro_cta_credito /*p_nro_cta_contra*/
                                 );
                return lf_for_number(v_can_aut_requeridas,3)||lf_for_number(v_nro_documento,15);
             elsif v_modo = 'A' then -- confirmación de operación
                -- seteo las variables
                v_nro_secuencia := 0;
                pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                                          v_fec_valor,
                                          v_cod_tra_padre, 'N', 'N',
                                          v_nro_secuencia,
                                          null, v_cod_ofi_origen, 9, 91);
                -- esta la cuenta en condiciones, verifico el horario
                lp_ver_horario;
                -- actualizo la cuenta de débito
                -- 10/05/2011 Ajustes segun AP-1617 Soporte IT
                v_mto_equ_local := null;
                if v_cod_mon_debito <> v_cod_mon_local   and
                   v_cod_mon_debito <> v_cod_mon_credito then

                   v_cotizacion    := v_cot_debito;
                   if v_cod_mon_debito = v_cod_mon_local then
                      v_mto_equ_local := v_monto;
                   else
                      v_mto_equ_local := round(v_cot_debito * v_monto,0);   
                   end if;
                else
                   v_cotizacion     := null;
                   v_mto_equ_local  := null;
                end if;
                pag_cta.PR_ACT_OPERACION(v_nro_cta_debito, v_hor_actual,'D',
                                         v_cod_mon_debito, v_monto,
                                         v_cod_tra_padre, 503, v_nro_operacion,
                                         v_cotizacion, v_cod_ofi_origen, 9, 91,
                                         null, null, nvl(v_concepto,'Transf. a '||v_nro_cta_credito),
                                         'N', v_nro_secuencia, v_fec_valor,
                                         null, null, v_mto_equ_local);
               if nvl(pag_cta.g_cod_error,0)= 0 then
                  if v_cod_mon_credito <> v_cod_mon_local  and
                     v_cod_mon_debito <> v_cod_mon_credito then

                     v_cotizacion    := v_cot_credito;
                     if v_cod_mon_debito = v_cod_mon_local then
                        v_mto_equ_local := v_monto;
                     end if;
                  else
                     v_cotizacion     := null;
                     v_mto_equ_local  := null;
                  end if;
                  pag_cta.PR_ACT_OPERACION(v_nro_cta_credito, v_hor_actual,'C',
                                           v_cod_mon_credito, v_mto_credito,
                                           v_cod_tra_padre, 602, v_nro_operacion,
                                           v_cot_credito, v_cod_ofi_origen, 9, 91,
                                           null, null, nvl(v_concepto,'Transf. de '||v_nro_cta_debito),
                                           'N', v_nro_secuencia, v_fec_valor,
                                           null, null, v_mto_equ_local);
                  if nvl(pag_cta.g_cod_error,0)<> 0 then
                     -- hubo error en el credito
                    v_cod_respuesta := paw_bce.v_cod_tra_invalida;
                  else
             -- Notificacion al debito
              BEGIN
                 v_res_notificacion:=PAW_NOT.fu_not_transferencias(v_nro_cta_debito, v_monto, v_cod_mon_debito, 'D', v_fec_valor);
              EXCEPTION
                 WHEN OTHERS THEN
                    NULL;
              END;
              --Notificacion al credito
              BEGIN
                 v_res_notificacion:=PAW_NOT.fu_not_transferencias(v_nro_cta_credito, v_mto_credito, v_cod_mon_credito, 'C', v_fec_valor);
              EXCEPTION
                 WHEN OTHERS THEN
                    NULL;
              END;                     
                  end if;
               else
                  -- hubo error en el debito
                  v_cod_respuesta := paw_bce.v_cod_tra_invalida;
               end if ;
             end if;
          end if;
       end if;
    end if;
    -- registro del movimiento
    lp_reg_operacion(v_nro_cta_debito /*p_nro_cuenta*/,
                     v_cod_mon_debito /*p_cod_moneda */,
                     v_monto /*p_monto*/,
                     v_nro_cta_credito /*p_nro_cta_contra*/
                     );
    -- no se responde nada, solo se debe setear el v_cod_respuesta
    return null;
end;
-- fin de 039-confirmacion de transferencia entre cuentas de diferentes titulares
-- 040  Consulta de cheques devueltos
function fu_pro_operacion_040(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_ver_todas      varchar2(1) := substr(p_parametros,66,1);   -- ver todas las cuentas s/n
v_nro_cta_especifica varchar2(16) := trim(substr(p_parametros,67,16)); -- cuenta especifica a consultar
-- datos a responder
v_can_detalles    number(3);     -- cantidad de cuentas
--
v_detalles        clob := null;   -- datos de las cuentas
v_det_movimientos clob;           -- detalle de los movimientos
-- variables
v_can_movimientos number(5);
v_fec_anterior date := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual, v_cod_ofi_origen, 1);

-- cursor de cuentas pasivas del cliente
cursor cuentas is
  select a.nro_cuenta, a.cod_modalidad cod_modalidad,
         fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina,a.nro_cuenta, a.cod_moneda) cta_formateada,
         fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta,
         fug_obt_des_modal(a.cod_modulo,a.cod_modalidad) des_tip_cuenta,
         a.cod_moneda cod_moneda, a.denominacion nom_cuenta,
         fu_obt_sal_actual(a.cod_modulo, a.cod_modalidad, a.nro_cuenta) sal_actual,
         a.cod_modulo
    from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
   where a.nro_cuenta = b.nro_cuenta
     and b.relacion IN ('O','P','Y')
     and b.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
     and a.cod_modulo = c.cod_modulo
     and a.cod_modalidad = c.cod_modalidad
     and a.estado = c.estado
     and c.activo = 'S'  -- solo cuentas activas
     and a.estado <> 'X' -- pendiente de verificacion
     and b.cod_modalidad in (31,41)
     and (v_ver_todas = 'S' or b.nro_cuenta = v_nro_cta_especifica); -- solo ve la cuenta recibida o todas
-- movimientos de cheques devueltos de camara y del exterior depositados en cuenta
cursor movimientos(p_nro_cuenta in varchar2) is
   select b.descripcion des_banco, a.nro_documento nro_cheque,
          a.monto monto, c.descripcion des_causa, trim(to_char(a.fecha, 'dd/mm/yyyy')) fecha
     from ge_causales c, ge_bancos b, gv_movimientos a
    where a.nro_cuenta = p_nro_cuenta
      and a.cod_mod_padre = 4
      and a.cod_mad_padre = 41
      and a.cod_tra_padre = 321
      and a.cod_transaccion in (522,503,182)
      and a.reversado = 'N'
      and a.estado = 'N'
      and a.cod_banco = b.cod_banco
      and a.cod_causa = c.cod_causa
      and a.fecha >= v_fec_actual - 30
      Order by a.fecha desc;
begin
  -- 0. Armo el nro de cuenta
  v_nro_cta_especifica := lf_obt_cta_limpia(v_nro_cta_especifica);
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  
  --Verifica los permisos  
    if v_cod_respuesta = paw_bce.v_cod_aprobado then
       v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '040');
       if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
          v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
       end if;
    end if;        
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     v_can_detalles := 0;
     for ct in cuentas loop
       --- Debe controlar para que no muestre cuentas juridicas entre las cuentas del cliente
       If fu_es_juridica(ct.nro_cuenta) = 'N' then
         v_can_detalles := v_can_detalles + 1;
         v_detalles :=  v_detalles ||
                        lf_for_char(ct.cta_formateada,17)||
                        lf_for_char(ct.cod_tip_cuenta,2)||
                        lf_for_char(ct.des_tip_cuenta,35)||
                        lf_for_char(ct.nom_cuenta,50)||
                        lf_for_char(rpad(ct.cod_moneda,3,'.'),3)||
                        lf_for_money(ct.sal_actual,16);
         v_can_movimientos := 0;
         v_det_movimientos := null;
         for mv in movimientos(ct.nro_cuenta) loop
               v_can_movimientos := v_can_movimientos + 1;
               v_det_movimientos := v_det_movimientos ||
                         lf_for_char(mv.des_banco,35)||
                         lf_for_number(mv.nro_cheque,10)||
                         lf_for_money(mv.monto,16)||
                         lf_for_char(mv.des_causa,35)||
                         mv.fecha;
         end loop;
         if v_cod_respuesta = paw_bce.v_cod_aprobado then
            -- esta bien el dato se carga el detalle
            v_detalles := v_detalles ||
                          lf_for_number(v_can_movimientos,3)||
                          v_det_movimientos;
         end if;
       end if;
     end loop;
     if v_can_detalles = 0 then
        -- no tiene detalles
         v_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
     end if;
  end if;
  -- registro del movimiento
  lp_reg_operacion(v_nro_cta_especifica /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Ver Todas' /*p_etiqueta*/,
                   v_ver_todas /*p_dato*/
                 );
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return lf_for_number(v_can_detalles,3)||
            v_detalles;
  else
     return null;  -- nada
  end if;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 040 - consulta de cheques devueltos


-- 041  Depositos a confirmar por cuenta
function fu_pro_operacion_041(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_ver_todas      varchar2(3)      := substr(p_parametros,66,1);   -- ver todas las cuentas s/n
v_nro_cta_especifica varchar2(16) := trim(substr(p_parametros,67,16)); -- cuenta especifica a consultar
-- datos a responder
v_can_detalles    number(3);     -- cantidad de cuentas
--
v_detalles        clob := null;   -- datos de las cuentas
v_det_movimientos clob;           -- detalle de los movimientos
-- variables
v_che_devuelto    varchar2(01);
v_can_movimientos number(5);

-- cursor de cuentas pasivas del cliente
cursor cuentas is
  select a.nro_cuenta, a.cod_modalidad cod_modalidad,
         fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina,a.nro_cuenta, a.cod_moneda) cta_formateada,
         fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta,
         fug_obt_des_modal(a.cod_modulo,a.cod_modalidad) des_tip_cuenta,
         a.cod_moneda cod_moneda, a.denominacion nom_cuenta,
         a.cod_modulo
    from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
   where a.nro_cuenta = b.nro_cuenta
     and b.relacion IN ('O', 'P','Y')
     and b.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
     and a.cod_modulo = c.cod_modulo
     and a.cod_modalidad = c.cod_modalidad
     and a.estado = c.estado
     and c.activo = 'S'  -- solo cuentas activas
     and a.estado <> 'X' -- pendiente de verificacion
     and b.cod_modalidad in (31,41)
     and (v_ver_todas = 'S' or b.nro_cuenta = v_nro_cta_especifica); -- solo ve la cuenta recibida o todas
-- movimientos de depositos a cofirmar por cuenta
cursor movimientos(p_nro_cuenta in varchar2) is
  select nro_documento, monto, fec_inicio, fec_final
    from ah_retenciones
   where nro_cuenta = p_nro_cuenta
     and liberado = 'N'
     and 
       ( -- Discriminar depositos a confirmar en efectivo para el IVR
         paw_bce.v_nro_terminal <> '888' or 
         (paw_bce.v_nro_terminal = '888' and cod_retencion <> 7)
       )
   order by fec_inicio, fec_final;

begin
  -- 0. Armo el nro de cuenta
  v_nro_cta_especifica := lf_obt_cta_limpia(v_nro_cta_especifica);
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     v_can_detalles := 0;
     for ct in cuentas loop
       --- Debe controlar para que no muestre cuentas juridicas entre las cuentas del cliente
       If fu_es_juridica(ct.nro_cuenta) = 'N' then
         v_can_detalles := v_can_detalles + 1;

         pag_cta.PR_OBT_CUENTA(ct.nro_cuenta);
         v_detalles :=  v_detalles ||
                        lf_for_char(ct.cta_formateada,17)||
                        lf_for_char(ct.cod_tip_cuenta,2)||
                        lf_for_char(ct.des_tip_cuenta,35)||
                        lf_for_char(ct.nom_cuenta,50)||
                        lf_for_char(rpad(ct.cod_moneda,3,'.'),3)||
                        lf_for_money(pag_cta.g_ctas.sal_retenido,16);
         v_che_devuelto    := 'N';
         v_can_movimientos := 0;
         v_det_movimientos := null;
         for mv in movimientos(ct.nro_cuenta) loop
               v_can_movimientos := v_can_movimientos + 1;
               v_det_movimientos := v_det_movimientos ||
                         lf_for_number(mv.nro_documento,7)||
                         lf_for_money(mv.monto,16)||
                         lf_for_date(mv.fec_inicio)||
                         lf_for_date(mv.fec_final);
         end loop;
         if v_cod_respuesta = paw_bce.v_cod_aprobado then
            v_che_devuelto := lf_obt_che_devuelto(ct.nro_cuenta);
            -- esta bien el dato se carga el detalle
            v_detalles := v_detalles ||
                          lf_for_char(v_che_devuelto,1)||
                          lf_for_number(v_can_movimientos,3)||
                          v_det_movimientos;
         end if;
       end if;
     end loop;
     if v_can_detalles = 0 then
        -- no tiene detalles
         v_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
     end if;
  end if;
  -- registro del movimiento
  lp_reg_operacion(v_nro_cta_especifica /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Ver Todas' /*p_etiqueta*/,
                   v_ver_todas /*p_dato*/
                 );
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return lf_for_number(v_can_detalles,3)||
            v_detalles;
  else
     return null;  -- nada
  end if;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 041 - depositos a confirmar por cuenta


-- Devuelve las cotizaciones de cuatro monedas
function fu_pro_operacion_050(p_parametros in varchar2)
  return varchar2 is
-- datos a responder
v_can_detalles   number(3) := 0;     -- cantidad de cuentas
--
v_detalles       varchar2(4000) := null; -- datos de las cuentas
-- cursor de  cotizaciones
cursor cotizaciones is
  select a.cod_moneda cod_moneda, c.descripcion des_moneda,
         val_compra, val_venta,
         decode(val_com_electronica,0,val_compra,val_com_electronica) val_com_electronica,
         decode(val_ven_electronica,0,val_venta ,val_ven_electronica) val_ven_electronica
    from ba_monedas c,ge_cotizaciones a
   where a.cod_moneda in ('USD','EUR') --,'BRL','ARS')
     and a.cod_moneda = c.cod_moneda
     and fecha = (select max(fecha)
                    from ge_cotizaciones b
                   where b.cod_moneda = a.cod_moneda)
    order by decode(a.cod_moneda,'USD',1,'EUR',2) ; --,'BRL',3,'ARS',4);

begin
   for ct in cotizaciones loop
       v_can_detalles := v_can_detalles + 1;
       v_detalles :=  v_detalles ||
                      lf_for_char(ct.des_moneda,30)||
                      lf_for_money(ct.val_compra,16)||
                      lf_for_money(ct.val_venta,16)||
                      lf_for_money(ct.val_com_electronica,16)||
                      lf_for_money(ct.val_ven_electronica,16);
   end loop;
   if v_can_detalles = 0 then
      -- no tiene cuentas
       v_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
   end if;
   --
   if v_cod_respuesta = paw_bce.v_cod_aprobado then
      -- todo ok, se arma el mensaje de respuesta
      return lf_for_number(v_can_detalles,3)||
               v_detalles;
   else
      return null;  -- nada
   end if;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de consulta de cotizaciones

-- 060 Solicitud de chequeras
function fu_pro_operacion_060(p_parametros    in varchar2,
                              p_nro_cta_cte   in varchar2 default null,
                              p_modo          in varchar2 default null,
                              p_tip_chequera  in varchar2 default null,
                              p_can_chequera  in number   default null,
                              p_ofi_retencion in number  default null)
  return clob is
-- datos recibidos
v_nro_cta_cte     varchar2(16); -- nro de cta corriente
v_modo            varchar2(3);   -- modo S/V/C
--
v_sol_tip_che varchar(7);
v_sol_can_che number(4);
v_sol_ofi_ret number(3);
-- datos a responder
v_can_agencias    number(3);     -- cantidad de agencias
v_can_tip_che     number(3);     -- cantidad de tipos de chequeras
--
v_det_agencias    varchar2(2000); -- datos de las cuentas
v_det_tip_che     varchar2(1000); -- datos de los tipos de chequeras
v_can_chequera    varchar2(100);  -- cantidad de chequeras
v_cantidad        varchar2(5);
v_pos             number(5);
v_cod_moneda      varchar2(4);
v_des_cuenta      varchar2(100);
v_existe          varchar2(1) := 'N';
v_nro_documento   number(15);
v_des_chequera    varchar2(200);
v_ver_can_cheques number(3);
v_ver_can_minima  number(5);
v_ver_can_maxima  number(5);
v_ver_cod_moneda  varchar2(3);
-- cursor de agencias
cursor agencias is
  select cod_oficina, replace(descripcion,'Ñ','N') descripcion
    from ba_oficinas
   where estado = 'A'
     and cod_oficina not in (31);  -- no se toma la casa matriz para el bbva
-- tipos de chequeras
cursor tip_cheq is
  select cod_tip_chequera, descripcion, can_cheques, tipo, can_maxima, cod_moneda,
         cod_transaccion
    from cc_tip_chequeras
   where (cod_moneda is null or cod_moneda = v_cod_moneda) ;
   -- OMM 20/01/2011 Para Formulario Continuo
   --  and can_cheques<>'1';

begin
  if nvl(p_modo,'x') = 'A' then
     -- viene de confirmacion de una autorizacion
   -- OMM 01/06/2011 Reclamo de Soporte AP 1987
     v_nro_cta_cte     := p_nro_cta_cte;
     v_modo            := p_modo;
     v_sol_tip_che     := p_tip_chequera;
     v_sol_can_che     := p_can_chequera;
     v_sol_ofi_ret     := p_ofi_retencion;
  else
     v_nro_cta_cte     := lf_obt_cta_limpia(substr(p_parametros,66,16)); -- nro de tarjeta a pagar
     v_modo            := substr(p_parametros,82,1);   -- modo S/V/C
     -- 1. valido la clave del cliente
     pr_val_clave(p_parametros);
     if v_modo = 'C' and v_can_aut_requeridas = 0 then
        -- se confirma directamente la operacion, porque no requiere autorizacion
        v_modo := 'A'; -- CONFIRMACION
     end if;
     -- Valida la cantidad ingresada.
     if substr(p_parametros,88,5) < 1 then
        v_cod_respuesta := paw_bce.v_can_che_invalida;
     end if;
  end if;    
  -- Verifico si el cliente con su perfil tendrá acceso a realizar la transaccion
  if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(v_modo,'x') <> 'A' then
     v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '060');
     if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
        v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
     end if;
  end if;
  
  -- valido que la cuenta perteneza a la persona
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if lf_val_cta_origen(v_nro_cta_cte, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;  
    end if;
  end if;
  
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     begin
        select cod_moneda, denominacion
          into v_cod_moneda, v_des_cuenta
          from cc_cta_corrientes
         where nro_cuenta = v_nro_cta_cte
           and estado = 'N';
     exception
         when others then
           v_cod_respuesta := paw_bce.v_cod_cta_invalida;
     end;
     if v_cod_respuesta = paw_bce.v_cod_aprobado then
       if v_modo = 'S' then -- seleccion de datos
           v_can_agencias := 0;
           v_det_agencias := null;
           for ag in agencias loop
               v_can_agencias := v_can_agencias + 1;
               v_det_agencias := v_det_agencias||
                                 lf_for_number(ag.cod_oficina,3)||
                                 lf_for_char(ag.descripcion,35);
           end loop;
           v_can_tip_che := 0;
           v_det_tip_che := null;
           for tc in tip_cheq loop
              if pag_cta.fu_ver_tra_prohibida(v_nro_cta_cte,tc.cod_transaccion,4, 41) = 'N' then
                  -- no tiene transaccion prohibida
                  v_can_chequera := replace(trim(tc.can_cheques),' ','');
                  loop -- ciclo para desmembrar el campo de cantidad posibles de chequeras
                   exit when v_can_chequera is null;
                   v_pos := instr(v_can_chequera,',');
                   if v_pos > 0 then
                      v_cantidad := substr(v_can_chequera,1,v_pos-1);
                      v_can_chequera := substr(v_can_chequera,v_pos+1);
                   else
                      v_cantidad := v_can_chequera;
                      v_can_chequera := null;
                   end if;
                   v_can_tip_che := v_can_tip_che + 1;
                   v_det_tip_che := v_det_tip_che||
                                    lf_for_char(tc.cod_tip_chequera,1)||
                                    lf_for_char(tc.tipo,1)||
                                    lf_for_char(v_cantidad,3)||
                                    lf_for_char(tc.descripcion||' '||v_cantidad,20);

                  end loop;
               end if;
           end loop;
           if v_can_agencias = 0 or v_can_tip_che = 0 then
              -- no tiene detalles
               v_cod_respuesta  := paw_bce.v_can_che_invalida;
           end if;
           -- fin de la seleccion
           if v_cod_respuesta = paw_bce.v_cod_aprobado then
               -- todo ok, se arma el mensaje de respuesta
               return lf_for_number(v_can_tip_che,3)||
                      lf_for_number(v_can_agencias,3)||
                      lf_for_char(v_des_cuenta,50)||
                      v_det_tip_che||
                      v_det_agencias||v_det_agencias;
           else
               return null;  -- nada
           end if;
       elsif v_modo = 'C' then -- grabar en modo de pendientes
          -- OMM 02/02/2011 Para Formulario Continuo -- 01/06/2011 Reclamo de Soporte AP 1987
           if trim(substr(p_parametros,85,3)) = '1' then
               v_sol_tip_che := substr(p_parametros,83,2)|| substr(p_parametros,88,5);
               v_sol_can_che := substr(p_parametros,85,3);
               v_sol_ofi_ret := substr(p_parametros,93,3);
           else
               v_sol_tip_che := substr(p_parametros,83,5);
               v_sol_can_che := substr(p_parametros,88,5);
               v_sol_ofi_ret := substr(p_parametros,93,3);
           end if ;
           v_des_chequera := lf_obt_des_chequera(v_sol_tip_che);
           --- inserto el movimiento pendiente de autorizacion
            select s_nro_documento.nextval into v_nro_documento from dual;
            insert into bw_mov_pendientes
              (nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda,
               descripcion, etiqueta, dato, cantidad, etiqueta2, dato2,
               estado,can_aut_requeridas, can_aut_faltantes, cod_per_ingreso)
            values
               (v_nro_documento,nvl(v_cod_per_empresa,v_cod_persona),sysdate,'060',v_nro_cta_cte,
                v_cod_moneda,
                'Solicitud de Chequeras', 'Tipo de Chequera',
                substr(rpad(v_sol_tip_che,8,' ')||v_des_chequera,1,50), v_sol_can_che,
                'Ofi.de Retencion',
                substr(rpad(v_sol_ofi_ret,4,' ')||fue_obt_des_oficina(v_sol_ofi_ret),1,50),
                'P', v_can_aut_requeridas, v_can_aut_requeridas, v_cod_persona
               );
            return lf_for_number(v_can_aut_requeridas,3)||lf_for_number(v_nro_documento,15);

       elsif v_modo = 'A' then -- confirmacion de datos
           if nvl(p_modo,'x') <> 'A' then
               -- OMM 02/02/2011 Para Formulario Continuo
               if trim(substr(p_parametros,85,3)) = '1' then
                   v_sol_tip_che := substr(p_parametros,83,2)|| substr(p_parametros,88,5);
                   v_sol_can_che := substr(p_parametros,85,3);
                   v_sol_ofi_ret := substr(p_parametros,93,3);
                   -- Solo personas Juridicas pueden solicitar Formulario Continuo.
                   If fu_es_juridica(v_nro_cta_cte) = 'N' and substr(v_sol_tip_che,1,1) in (5,6) then    
                       v_cod_respuesta := v_cod_tra_invalida;   
                   end if;
               else
                   v_sol_tip_che := substr(p_parametros,83,5);
                   v_sol_can_che := substr(p_parametros,88,5);
                   v_sol_ofi_ret := substr(p_parametros,93,3);
               end if ;
           end if;
           -- registro del movimiento
           lp_reg_operacion(v_nro_cta_cte /*p_nro_cuenta*/,
                            v_cod_moneda /*p_cod_moneda */,
                            null /*p_monto*/,
                            null /*p_nro_cta_contra*/,
                            v_sol_can_che /*p_cantidad*/,
                            'Tipo' /*p_etiqueta*/,
                            v_sol_tip_che /*p_dato*/,
                            'Ofi.Retencion',
                            v_sol_ofi_ret
                            );
           declare
              v_cod_transaccion number(4);
           begin
               -- busco la transaccion que corresponde para verificar prohibiciones
               select cod_transaccion
                 into v_cod_transaccion
                 from cc_tip_chequeras
                where cod_tip_chequera = substr(v_sol_tip_che,1,1)
                  and (cod_moneda is null or cod_moneda = v_cod_moneda);
               if pag_cta.fu_ver_tra_prohibida(v_nro_cta_cte,v_cod_transaccion,4, 41) = 'N' then
 
                begin
                  select a.can_cheques, nvl(a.can_minima,1), nvl(a.can_maxima,999999999), a.cod_moneda
                  into v_ver_can_cheques, v_ver_can_minima, v_ver_can_maxima, v_ver_cod_moneda
                  from cc_tip_chequeras a
                  where a.cod_tip_chequera = substr(v_sol_tip_che,1,1);
                  -- Para Validar Cantidad de hojas de Formularios Continuo.
                  if substr(v_sol_tip_che,1,1) in (5,6) then
                     if not (substr(v_sol_tip_che,3,5) between v_ver_can_minima and v_ver_can_maxima) or (v_sol_can_che=0) then
                      v_cod_respuesta := paw_bce.v_can_che_invalida;
                     end if;
                  else
                  -- Para Validar Cantidad de hojas de Chequeras.
                  if not (v_sol_can_che between v_ver_can_minima and v_ver_can_maxima) or (v_sol_can_che=0) then
                    v_cod_respuesta := paw_bce.v_can_che_invalida;
                     end if;
                  end if;
                exception
                  when no_data_found then
                      v_cod_respuesta := v_can_che_invalida;
                end;
                    
                  Begin
                     -- Antes de insertar verifico si es que no existe un pedido similar.
                      select 'S' into v_existe
                        from cc_sol_chequeras
                       where nro_cuenta = v_nro_cta_cte
                         and cod_tip_chequera = substr(v_sol_tip_che,1,1)
                         and cantidad = v_sol_can_che
                         and can_hojas = substr(v_sol_tip_che,3,5)
                         and estado in ('S','V')
                         and rownum = 1;
                    exception
                       when no_data_found then
                          v_existe := 'N';
                       when too_many_rows then
                          v_existe := 'S';
                       when others then
                          v_existe := 'N';
                    end;
                    if v_existe = 'S' then
                       v_cod_respuesta := paw_bce.v_cod_ped_duplicado;
                    end if;
                   --inserto el registro de la solicitud de chequeras
                   if v_cod_respuesta = paw_bce.v_cod_aprobado then
                     insert into cc_sol_chequeras
                       (nro_cuenta, fecha, hora, cod_usuario, cod_tip_chequera,
                        cantidad, can_hojas, estado, cod_ofi_retiro, observacion)
                     values
                       (v_nro_cta_cte,v_fec_actual, v_hor_actual, v_cod_usuario,
                        substr(v_sol_tip_che,1,1), v_sol_can_che,
                        substr(v_sol_tip_che,3,5), 'S', v_sol_ofi_ret,
                        decode(fu_caj_homebanking(v_nro_terminal),'S','Solicitado a traves de la Web',
                        'Solicitado a traves del TAS'));
                   End if;
               else
                  v_cod_respuesta := paw_bce.v_cod_tra_prohibida;
               end if;
           exception
              when others then
                  v_cod_respuesta := paw_bce.v_cod_tra_prohibida;
           end;
           return null;
       end if;
     end if;
  end if;
  return null;
exception
  when others then
     v_cod_respuesta  := paw_bce.v_cod_otr_error;
end;
-- fin de la 060 - Solicitud de chequeras

-- 061 Consulta de Chequeras
function fu_pro_operacion_061(p_parametros in varchar2)
  return clob is
--
v_nro_cta_especifica varchar2(16) := lf_obt_cta_limpia(trim(substr(p_parametros,66,16)));
v_can_detalles    number(3);     -- cantidad de cuentas
v_cantidad        number(3);
--
v_detalles        clob := null;   -- datos de las cuentas
v_det_cheques     clob := null;
v_existe          varchar2(1) := 'N';
v_cod_moneda      cc_cta_corrientes.cod_moneda%type;
v_des_cuenta      cc_cta_corrientes.denominacion%type;
v_tip_cuenta      ge_modalidades.descripcion%type;
v_cta_formateada  varchar2(17);
-- tipos de chequeras
cursor c_tip_cheq is
  Select c.nro_che_inicial, c.nro_che_final,
         c.fec_solicitud,
         decode(c.nro_che_inicial, c.nro_che_final, 'CHEQUE VENTANILLA', t.descripcion) tipo,
         fue_obt_des_refcodes('EST_CHEQUE', c.estado) estado,
         c.est_cheques,
         c.can_cheques
    from cc_tip_chequeras t, cc_chequeras c
   where t.cod_tip_chequera = c.tipo
     and nro_cuenta = v_nro_cta_especifica
     Order by fec_solicitud desc;
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  
  -- valido que la cuenta perteneza a la persona
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if lf_val_cta_origen(v_nro_cta_especifica, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;  
    end if;
  end if;
    
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     begin
        select fug_cta_formateada(cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, cod_moneda),
               cod_moneda, denominacion, fug_obt_des_modal(cod_modulo, cod_modalidad)
          into v_cta_formateada, v_cod_moneda, v_des_cuenta, v_tip_cuenta
          from cc_cta_corrientes
         where nro_cuenta = v_nro_cta_especifica
           and estado = 'N';
     exception
         when others then
           v_cod_respuesta := paw_bce.v_cod_can_invalida;
     end;
     Begin
       Select nvl(count(*), 0)
         into v_can_detalles
         from cc_chequeras
        where nro_cuenta = v_nro_cta_especifica;
       If v_can_detalles > 40 then
          -- Se establece 40 como maximo.
          v_can_detalles := 40;
       End if;
     End;
     ---
     if v_cod_respuesta = paw_bce.v_cod_aprobado then
         v_detalles :=  v_detalles ||
                        lf_for_char(v_cta_formateada,17)||
                        lf_for_char(rpad(v_cod_moneda,3,'.'),3)||
                        lf_for_char(v_des_cuenta,50)||
                        lf_for_char(v_tip_cuenta,35)||
                        lf_for_char(v_can_detalles,3);
     end if;
     If v_can_detalles > 0 then
        v_cantidad := 0;
        For r1 in c_tip_cheq Loop
            v_det_cheques := v_det_cheques||
                         lf_for_char(r1.nro_che_inicial,7)||
                         lf_for_char(r1.nro_che_final,7)||
                         lf_for_date(r1.fec_solicitud)||
                         lf_for_char(r1.tipo,20)||
                         lf_for_char(r1.estado,20);
           v_cantidad := v_cantidad + 1;
           If v_cantidad = v_can_detalles then
              exit;
           End if;
        End Loop;
        v_detalles := v_detalles||v_det_cheques;
     End if;
     -- registro del movimiento
     lp_reg_operacion(v_nro_cta_especifica
                      );
     return v_detalles;
  end if;
  return null;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 061 - Consulta de Chequeras
-- 062 Consulta de Chequeras - Detalle de un cheque
function fu_pro_operacion_062(p_parametros in varchar2)
  return clob is
--
v_nro_cta_especifica varchar2(16) := trim(substr(p_parametros,66,16)); -- cuenta especifica a consultar
v_nro_cheque      cc_chequeras.nro_che_inicial%type := substr(p_parametros, 82, 7);
v_nro_inicial     cc_chequeras.nro_che_final%type;
--
v_can_detalles    number(3);     -- cantidad de cuentas
v_cantidad        number(3);
--
v_detalles        clob := null;   -- datos de las cuentas
v_det_cheques     clob := null;
v_existe          varchar2(1) := 'N';
v_des_cuenta      cc_cta_corrientes.denominacion%type;
v_tip_cuenta      ge_modalidades.descripcion%type;
v_cta_formateada  varchar2(17);
v_fec_solicitud   date;

v_tip_chequera    cc_tip_chequeras.descripcion%type;
v_estado          ba_cod_referencias.significado%type;
v_est_cheques     cc_chequeras.est_cheques%type;

v_can_cheques     cc_chequeras.can_cheques%type;
---
v_posicion         number(5);
v_pos              varchar2(1);
--- Variables
v_posee_det         varchar2(1);
v_desc_fecha        varchar2(20);
v_fecha             date;
v_hora              varchar2(8);
v_oficina           varchar2(35);
v_tipo_pago         varchar2(35);
v_cod_moneda        varchar2(3);
v_importe           number(18,2);
v_beneficiario      varchar2(35);
v_causa             varchar2(35);
v_fec_certificacion date;
-- tipos de chequeras
begin
  -- 0. Armo el nro de cuenta
  v_nro_cta_especifica := lf_obt_cta_limpia(v_nro_cta_especifica);
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  
  -- valido que la cuenta perteneza a la persona
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if lf_val_cta_origen(v_nro_cta_especifica, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;  
    end if;
  end if;
    
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     Begin
        Select cc_chequeras.fec_solicitud,
               cc_chequeras.hor_solicitud,
               cc_tip_chequeras.descripcion tipo,
               cc_chequeras.est_cheques,
               cc_chequeras.can_cheques,
               cc_chequeras.nro_che_inicial,
               cc_cta_corrientes.cod_moneda
          into v_fec_solicitud,
               v_hora,
               v_tip_chequera,
               v_est_cheques,
               v_can_cheques,
               v_nro_inicial,
               v_cod_moneda
          from cc_cta_corrientes, cc_tip_chequeras, cc_chequeras
         where cc_cta_corrientes.nro_cuenta = cc_chequeras.nro_cuenta
           and cc_tip_chequeras.cod_tip_chequera = cc_chequeras.tipo
           and cc_chequeras.nro_cuenta = v_nro_cta_especifica
           and cc_chequeras.nro_che_inicial <= v_nro_cheque
           and cc_chequeras.nro_che_final >= v_nro_cheque
           and cc_chequeras.fec_solicitud = (SELECT MAX(t.fec_solicitud) 
                                                FROM cc_chequeras t 
                                               WHERE t.nro_cuenta = v_nro_cta_especifica
                                                 AND t.nro_che_inicial <= v_nro_cheque 
                                                 AND t.nro_che_final >= v_nro_cheque );
        v_importe := null;
     Exception
        When NO_DATA_FOUND then
             v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
     End;
     ---
     if v_cod_respuesta = paw_bce.v_cod_aprobado then
        v_posicion := v_nro_cheque - v_nro_inicial + 1;
        If v_est_cheques is not null then
           v_pos    := substr(v_est_cheques, v_posicion, 1);
           v_estado := fue_obt_des_refcodes('EST_CHEQUE', v_pos);
        End if;
        If v_pos = 'P' then
           -- Si el cheque esta pagado
           v_desc_fecha := 'Pagado';
           Begin
             Select fecha, hora, substr(fue_obt_des_oficina(cod_ofi_origen), 1, 35),
                    monto, cod_moneda, substr(ge_causales.descripcion, 1, 35),
                    substr(fug_obt_des_transaccion(cod_modulo, cod_modalidad, cod_transaccion), 1, 35)
               into v_fecha, v_hora, v_oficina, v_importe, v_cod_moneda,
                    v_causa, v_tipo_pago
               from ge_causales, cc_che_pagados
              where ge_causales.cod_causa(+) = cc_che_pagados.cod_cau_devolucion
                and ge_causales.tipo(+) = 'D'
                and nro_cheque = v_nro_cheque
                and nro_cuenta = v_nro_cta_especifica;
             v_posee_det := 'S';
           Exception
              When NO_DATA_FOUND then
                   v_posee_det := 'N';
           End;
        Elsif v_pos = 'O' then
           -- Si el cheque tiene ONP.
           v_desc_fecha := 'Orden de no Pago';
           Begin
             Select fecha, hora,
                    monto, cc_cta_corrientes.cod_moneda, substr(ge_causales.descripcion, 1, 35),
                    substr(beneficiario, 1, 35)
               into v_fecha, v_hora, v_importe, v_cod_moneda,
                    v_causa, v_beneficiario
               from cc_cta_corrientes, ge_causales, cc_che_ord_no_pagos
              where cc_cta_corrientes.nro_cuenta = v_nro_cta_especifica
                and cc_cta_corrientes.nro_cuenta = cc_che_ord_no_pagos.nro_cuenta
                and ge_causales.cod_causa(+) = cc_che_ord_no_pagos.cod_causa
                and ge_causales.tipo(+) = 'O'
                and nro_cheque = v_nro_cheque
                and cc_che_ord_no_pagos.nro_cuenta = v_nro_cta_especifica;
             v_posee_det := 'S';
           Exception
              When NO_DATA_FOUND then
                   v_posee_det := 'N';
           End;
        Elsif v_pos = 'C' then
           -- Si el cheque esta certificado.
           v_desc_fecha := 'Pagado';
           Begin
             Select fecha,
                    monto, cc_cta_corrientes.cod_moneda, substr(ge_causales.descripcion, 1, 35),
                    substr(beneficiario,1,35), fec_pago
               into v_fec_certificacion, v_importe, v_cod_moneda,
                    v_causa, v_beneficiario, v_fecha
               from cc_cta_corrientes, ge_causales, cc_che_certificados
              where cc_cta_corrientes.nro_cuenta = v_nro_cta_especifica
                and cc_cta_corrientes.nro_cuenta = cc_che_certificados.nro_cuenta
                and ge_causales.cod_causa(+) = cc_che_certificados.cod_cau_devolucion
                and ge_causales.tipo(+) = 'D'
                and nro_cheque = v_nro_cheque
                and cc_che_certificados.nro_cuenta = v_nro_cta_especifica;
             v_posee_det := 'S';
           Exception
              When NO_DATA_FOUND then
                   v_posee_det := 'N';
           End;
        Elsif v_pos = 'G' then
           -- Si es un cheque Gerencia.
           v_desc_fecha := 'Gerencia';
           Begin
             Select fecha,
                    monto, cc_cta_corrientes.cod_moneda,
                    substr(beneficiario,1,35), fec_pago,
                    substr(fug_obt_des_transaccion(cc_che_ger_emitidos.cod_modulo, cc_che_ger_emitidos.cod_modalidad, cc_che_ger_emitidos.cod_transaccion),1,35)
               into v_fec_certificacion, v_importe, v_cod_moneda,
                    v_beneficiario, v_fecha, v_tipo_pago
               from cc_cta_corrientes, cc_che_ger_emitidos
              where cc_cta_corrientes.nro_cuenta = v_nro_cta_especifica
                and cc_cta_corrientes.nro_cuenta = cc_che_ger_emitidos.nro_cuenta
                and nro_cheque = v_nro_cheque
                and cc_che_ger_emitidos.nro_cuenta = v_nro_cta_especifica;
             v_posee_det := 'S';
           Exception
              When NO_DATA_FOUND then
                   v_posee_det := 'N';
           End;
        Elsif v_pos = 'S' then
           -- Si es un cheque solicitado
           v_desc_fecha := 'Solicitado';
           v_fecha      := v_fec_solicitud;
           v_posee_det  := 'S';
        Elsif v_pos = 'E' then
           -- Si es un cheque entregado.
           v_desc_fecha := 'Entregado';
           v_posee_det  := 'N';
        Elsif v_pos = 'A' then
           -- Si es un cheque Anulado
           v_desc_fecha := 'Anulado';
           Begin
             Select fecha, hora,
                    cc_cta_corrientes.cod_moneda, substr(ge_causales.descripcion, 1, 35)
               into v_fecha, v_hora,
                    v_cod_moneda,
                    v_causa
               from cc_cta_corrientes, ge_causales, cc_che_anulados
              where cc_cta_corrientes.nro_cuenta = v_nro_cta_especifica
                and cc_cta_corrientes.nro_cuenta = cc_che_anulados.nro_cuenta
                and ge_causales.cod_causa(+) = cc_che_anulados.cod_causa
                and ge_causales.tipo(+) = 'A'
                and nro_cheque = v_nro_cheque
                and cc_che_anulados.nro_cuenta = v_nro_cta_especifica;
             v_posee_det := 'S';
           Exception
              When NO_DATA_FOUND then
                   v_posee_det := 'N';
           End;
        End if;
     end if;
     ---
     -- registro del movimiento
     lp_reg_operacion( v_nro_cta_especifica /*p_nro_cuenta*/,
                       v_cod_moneda /*p_cod_moneda */,
                       null /*p_monto*/,
                       null /*p_nro_cta_contra*/,
                       null /*p_cantidad*/,
                       'Nro.Cheque' /*p_etiqueta*/,
                       v_nro_cheque /*p_dato*/
                     );
     ---
     v_detalles := v_detalles||
                   lf_for_char(v_estado, 20)||
                   v_posee_det||
                   lf_for_char(v_desc_fecha, 20)||
                   lf_for_date(v_fecha)||
                   lf_for_char(v_hora, 8)||
                   lf_for_char(v_oficina, 35)||
                   lf_for_char(v_tipo_pago, 35)||
                   lf_for_char(v_cod_moneda, 3)||
                   lf_for_money(v_importe, 16)||
                   lf_for_char(v_beneficiario,35)||
                   lf_for_char(v_causa, 35)||
                   lf_for_date(v_fec_certificacion);
     return v_detalles;
  end if;
  return null;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 062 - Consulta de Chequeras - Detalle de un cheque

-- 063 Consulta de Chequeras - Detalle de cheques
function fu_pro_operacion_063(p_parametros in varchar2)
  return clob is
--
v_nro_cta_especifica varchar2(16) := lf_obt_cta_limpia(trim(substr(p_parametros,66,16)));
v_nro_inicial     cc_chequeras.nro_che_inicial%type := substr(p_parametros, 82, 7);
v_nro_cheque       cc_chequeras.nro_che_final%type;
--
v_can_detalles    number(3);     -- cantidad de cuentas
v_cantidad        number(3);
--
v_detalles        clob := null;   -- datos de las cuentas
v_det_cheques     clob := null;
v_existe          varchar2(1) := 'N';
v_cod_moneda      cc_cta_corrientes.cod_moneda%type;
v_des_cuenta      cc_cta_corrientes.denominacion%type;
v_tip_cuenta      ge_modalidades.descripcion%type;
v_cta_formateada  varchar2(17);
v_fec_solicitud   date;

v_tip_chequera    cc_tip_chequeras.descripcion%type;
v_estado          ba_cod_referencias.significado%type;
v_est_cheques     cc_chequeras.est_cheques%type;
v_can_cheques     cc_chequeras.can_cheques%type;
---
v_can_solicitadas  number(5);
v_can_entregadas   number(5);
v_can_pagadas      number(5);
v_can_anuladas     number(5);
v_can_onp          number(5);
v_can_certificadas number(5);
---
v_pos varchar2(1);
-- tipos de chequeras
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  
  -- valido que la cuenta perteneza a la persona
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if lf_val_cta_origen(v_nro_cta_especifica, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;  
    end if;
  end if;
   
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     Begin
        Select c.fec_solicitud,
               t.descripcion tipo,
               c.est_cheques,
               c.can_cheques
          into v_fec_solicitud,
               v_tip_chequera,
               v_est_cheques,
               v_can_cheques
          from cc_tip_chequeras t, cc_chequeras c
         where t.cod_tip_chequera = c.tipo
           and nro_cuenta = v_nro_cta_especifica
           and nro_che_inicial = v_nro_inicial;
     End;
     ---
     if v_cod_respuesta = paw_bce.v_cod_aprobado then
         v_detalles :=  v_detalles ||
                        lf_for_char(v_can_cheques,3);
     end if;
     If v_can_cheques > 0 then
        v_nro_cheque := v_nro_inicial;
        for i in 1..v_can_cheques loop
          v_pos := substr(v_est_cheques,i,1);
          v_det_cheques := v_det_cheques||
                           lf_for_char(v_nro_cheque,7)||
                           lf_for_char(fue_obt_des_refcodes('EST_CHEQUE', v_pos),20);
          v_nro_cheque := v_nro_cheque + 1;
        end loop;
        ---
        v_detalles := v_detalles||
                      v_det_cheques;
     Else
        v_cod_respuesta := paw_bce.v_cod_cta_sin_mov;
     End if;
     -- registro del movimiento
     lp_reg_operacion( v_nro_cta_especifica /*p_nro_cuenta*/,
                       v_cod_moneda /*p_cod_moneda */,
                       null /*p_monto*/,
                       null /*p_nro_cta_contra*/,
                       null /*p_cantidad*/,
                       'Nro.inicial' /*p_etiqueta*/,
                       v_nro_inicial /*p_dato*/
                     );
     return v_detalles;
  end if;
  return null;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 063 - Consulta de Chequeras - Detalle de Cheques

-- 064 Consulta de Chequeras - Detalle de una chequera
function fu_pro_operacion_064(p_parametros in varchar2)
  return clob is
--
v_nro_cta_especifica varchar2(16) := lf_obt_cta_limpia(trim(substr(p_parametros,66,16)));
v_nro_inicial     cc_chequeras.nro_che_inicial%type := substr(p_parametros, 82, 7);
v_nro_final       cc_chequeras.nro_che_final%type;
--
v_can_detalles    number(3);     -- cantidad de cuentas
v_cantidad        number(3);
--
v_detalles        clob := null;   -- datos de las cuentas
v_det_cheques     clob := null;
v_existe          varchar2(1) := 'N';
v_cod_moneda      cc_cta_corrientes.cod_moneda%type;
v_des_cuenta      cc_cta_corrientes.denominacion%type;
v_tip_cuenta      ge_modalidades.descripcion%type;
v_cta_formateada  varchar2(17);
v_fec_solicitud   date;

v_tip_chequera    cc_tip_chequeras.descripcion%type;
v_estado          ba_cod_referencias.significado%type;
v_est_cheques     cc_chequeras.est_cheques%type;
v_can_cheques     cc_chequeras.can_cheques%type;
---
v_can_solicitadas  number(5);
v_can_entregadas   number(5);
v_can_pagadas      number(5);
v_can_anuladas     number(5);
v_can_onp          number(5);
v_can_certificadas number(5);
---
v_pos varchar2(1);
-- tipos de chequeras
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  
  -- valido que la cuenta perteneza a la persona
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if lf_val_cta_origen(v_nro_cta_especifica, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;  
    end if;
  end if;
  
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     Begin
        Select c.nro_che_final,
               c.fec_solicitud,
               t.descripcion tipo,
               fue_obt_des_refcodes('EST_CHEQUE', c.estado) estado,
               c.est_cheques,
               c.can_cheques
          into v_nro_final, v_fec_solicitud,
               v_tip_chequera,
               v_estado,
               v_est_cheques,
               v_can_cheques
          from cc_tip_chequeras t, cc_chequeras c
         where t.cod_tip_chequera = c.tipo
           and nro_cuenta = v_nro_cta_especifica
           and nro_che_inicial = v_nro_inicial;
     End;
     ---
     if v_cod_respuesta = paw_bce.v_cod_aprobado then
         v_detalles :=  v_detalles ||
                        lf_for_char(v_can_cheques,3)||
                        '006';
     end if;
     If v_can_cheques > 0 then
        v_can_solicitadas  := 0;
        v_can_entregadas   := 0;
        v_can_pagadas      := 0;
        v_can_anuladas     := 0;
        v_can_onp          := 0;
        v_can_certificadas := 0;
        for i in 1..v_can_cheques loop
          v_pos := substr(v_est_cheques,i,1);
          if v_pos = 'S' then
            v_can_solicitadas := v_can_solicitadas + 1;
          elsif v_pos = 'E' then
            v_can_entregadas := v_can_entregadas + 1;
          elsif v_pos = 'P' then
            v_can_pagadas := v_can_pagadas + 1;
          elsif v_pos = 'A' then
            v_can_anuladas := v_can_anuladas + 1;
          elsif v_pos = 'O' then
            v_can_onp := v_can_onp + 1;
          elsif v_pos = 'C' then
            v_can_certificadas := v_can_certificadas + 1;
          end if;
        end loop;
        ---
        v_detalles := v_detalles||
                        lf_for_char(fue_obt_des_refcodes('EST_CHEQUE', 'S'),20)||
                        lf_for_char(v_can_solicitadas,3)||
                        lf_for_char(fue_obt_des_refcodes('EST_CHEQUE', 'E'),20)||
                        lf_for_char(v_can_entregadas,3)||
                        lf_for_char(fue_obt_des_refcodes('EST_CHEQUE', 'P'),20)||
                        lf_for_char(v_can_pagadas,3)||
                        lf_for_char(fue_obt_des_refcodes('EST_CHEQUE', 'A'),20)||
                        lf_for_char(v_can_anuladas,3)||
                        lf_for_char(fue_obt_des_refcodes('EST_CHEQUE', 'O'),20)||
                        lf_for_char(v_can_onp,3)||
                        lf_for_char(fue_obt_des_refcodes('EST_CHEQUE', 'C'),20)||
                        lf_for_char(v_can_certificadas,3);
     Else
        v_cod_respuesta := paw_bce.v_cod_cta_sin_mov;
     End if;
     -- registro del movimiento
     lp_reg_operacion( v_nro_cta_especifica /*p_nro_cuenta*/,
                       v_cod_moneda /*p_cod_moneda */,
                       null /*p_monto*/,
                       null /*p_nro_cta_contra*/,
                       null /*p_cantidad*/,
                       'Nro.inicial' /*p_etiqueta*/,
                       v_nro_inicial /*p_dato*/
                     );
     return v_detalles;
  end if;
  return null;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 064 - Consulta de Chequeras - Detalle de una chequera

-- control y actualizacion de pago de sueldos
function fu_pro_operacion_070(p_parametros in clob)
  return clob is
-- datos recibidos
p_modo           varchar2(1); -- modo de control L:ABM V:ARCHIVO
p_cod_ente       number(5);
p_cod_moneda     varchar2(3);             -- moneda
p_tot_debito     number(18,2); -- monto total sueldos
p_tip_remuneracion varchar2(1);   -- Tipo de remuneracion
p_can_cuentas    number(5);  -- cantidad de cuentas
p_can_registros  number(5);  -- cantidad de registros leidos
-- variables
v_cta_formateada varchar2(17);  -- cuenta formateada
v_cod_tip_cuenta varchar2(2);   -- codigo del tipo de cuenta
v_des_tip_cuenta varchar2(35);  -- descripcion del tipo de cuenta
v_cod_moneda     varchar2(3);   -- moneda de la cuenta
v_nom_cuenta     varchar2(100); -- nombre de la cuenta
v_cod_res_cta    varchar2(3);   -- respuesta por cada cuenta
-- datos de los detalles
v_nro_cuenta     varchar2(17);      -- contiene los numeros de cuentas
v_monto          number(18,2);      -- monto del credito
-- datos a responder
v_tot_detalles   number(18,2) := 0; -- total a debitar
v_can_detalles   number(5)    := 0; -- cantidad de cuentas
--
v_detalles       clob := null; -- datos de las cuentas
--
v_cod_ente       number(6);         -- codigo del ente
v_des_ente       varchar2(100);     -- descripcion del ente
v_nro_cta_debito varchar2(17);      -- cuenta de debito
--v_res_principal  varchar2(03) := '000'; -- respuesta

v_registro       varchar2(200);
v_for_archivo    varchar2(100);
v_tipo           varchar2(10);
v_can_creditos   number(5) := 0; -- Cantidad de Creditos
v_lon_registro   number(2) := 74; -- longitud de registro para archivos
v_nro_documento  varchar2(15);
v_nro_archivo    number(10) ; -- Nro de archivo a agrupar
--v_aux_nro_archivo number(10); -- BBVADES-2376
--v_tip_pro_sueldo varchar2(1); -- BBVADES-2376
v_det_temporal   long := null;
-- para control de límites
v_res_limite      varchar2(2);
v_ini_lim_param   number;
--
v_redondeo       number;
v_can_cta_debito number := 0; -- Cantidad de cuentas para débito
v_dir_correo     ge_par_dinamicos.val_parametro%type;
v_cod_transaccion ge_transacciones.cod_transaccion%type;
v_cod_tra_padre   ge_transacciones.cod_transaccion%type;
v_cod_modulo      ge_cuentas.cod_modulo%type;
v_traspaso        ge_par_dinamicos.val_parametro%type := 'N';
v_cod_error       number;
v_mensaje         varchar2(40);
begin
   v_lugar  := 'Datos del parametro';
   p_modo              := substr(p_parametros,66,1); -- modo de control L:ABM V:ARCHIVO
   p_cod_ente          := to_number(substr(p_parametros,67,5));
   p_cod_moneda        := trim(substr(p_parametros,72,3));             -- moneda
   p_tot_debito        := to_number(substr(p_parametros,75,16)); -- monto total sueldos
   p_tip_remuneracion  := substr(p_parametros,91,1);   -- Tipo de remuneracion
   p_can_cuentas       := to_number(substr(p_parametros,92,5));  -- cantidad de cuentas
   p_can_registros     := to_number(substr(p_parametros,97,5));  -- cantidad de registros leidos
   v_redondeo          := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',NULL,NULL,p_cod_moneda,null,null);

   if p_modo <> 'V' then
      -- formato fijo, porque se cargo por la pantalla
      v_lon_registro := 32; -- cuenta 15, monto 16, Tipo Cta (C,D) -- OMM 07/10/2010
   end if;
   -- 1. valido la clave del cliente
   v_lugar := 'Validacion de la clave';
   pr_val_clave(substr(p_parametros,1,100));
   -- Verifico si el cliente con su perfil tendrá acceso a realizar la transacción
   v_lugar := 'Control de permisos';
   if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(p_modo,'x') <> 'A' then
     v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '070');
     if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
        v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
     end if;
   end if;
   v_lugar := 'Datos del Ente';
   -- 2. Verifico si la persona tiene el servicio de pago de sueldos
   if v_cod_respuesta = paw_bce.v_cod_aprobado then
     begin
        select a.cod_ente, a.descripcion,
               fug_obt_parentes(a.cod_ente,'NRO_CTA_DEBITO'),
               fug_obt_parentes(a.cod_ente,'REFERENCIA_TXT_SUELDO')
          into v_cod_ente, v_des_ente, v_nro_cta_debito, v_for_archivo
          from ge_entes a
         where a.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
           and a.tipo = 'SU'
           and a.cod_ente = p_cod_ente
           and fug_obt_parentes(a.cod_ente,'SER_ACTIVO') = 'S'
           and fug_obt_parentes(a.cod_ente,'HAB_HOMEBANKING') = 'S';
     exception
        when too_many_rows then
           v_cod_respuesta := paw_bce.v_cod_cta_duplicada;
        when others then
            v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
     end;
     /* OMM 13/01/2011 --Se agrego esta validaciòn solo para el BBVA por mala
     configuraciòn del OAS de Produccion en ITGF (el parametro "NLS_NUMERIC_CHARACTER" no estaba
   configurado en el OAS por esto se procesa con otro tipo de archivo en USD)   */
     if v_for_archivo = 'PAG_SUELDOS_USD' then
         v_for_archivo := 'PAG_SUELDOS' ;
     end if ;
   end if;
   -- Se elimina verificación de existencia de pago pendiente de aprobación a pedido del cliente
   
   -- 3. Tomo la cantidad de cuentas recibidas
   if v_cod_respuesta = paw_bce.v_cod_aprobado then
     If p_modo = 'C' then -- Es confirmacion y no hubo errores...
       /* v_lugar := 'Limpiando datos de temporales';
        -- Al confirmar debe insertar en ge_pag_sueldos_tmp.
        pag_sue.LP_DEL_DATOS_TEMPORA(v_cod_ente, v_fec_actual, v_lugar);
        -- borro el mov pendiente si existe
        delete from bw_mov_pendientes
         where cod_tip_mensaje = '070'
           and estado = 'P'
           and trunc(fec_hora) < trunc(sysdate)
           and dato = trim(to_char(p_cod_ente))
           and cod_per_principal = nvl(v_cod_per_empresa,v_cod_persona);*/

         /*
         -- OMM 07/12/2010 Se carga la variable del nro archivo
         Begin
            Select distinct nvl(max(ge.nro_archivo), 0)
              into v_nro_archivo
              from ge_pag_sueldos_tmp ge
             where ge.cod_ente = v_cod_ente
               and ge.fec_envio = v_fec_actual; -- BBVADES-2376
         exception
            when others then
               v_nro_archivo := 1; -- BBVADES-2376
         end;
         -- BBVADES-2376: Ajuste para obtener el numero de archivo
         begin
            v_tip_pro_sueldo := nvl(fug_obt_parentes(v_cod_ente, 'TIP_PRO_SUELDO'), 'O');
         exception
            when others then
               v_tip_pro_sueldo := 'O';
         end;
         if v_tip_pro_sueldo = 'O' then
            begin
               select distinct nvl(max(gs.nro_secuencia), 0)
                 into v_aux_nro_archivo
                 from ge_pag_sueldos gs
                where gs.cod_ente = v_cod_ente
                  and gs.fec_proceso = v_fec_actual;
            exception
               when others then
                  v_aux_nro_archivo := 1;
            end;
            if v_aux_nro_archivo = 0 then
               begin
                  select distinct nvl(max(se.nro_secuencia), 0)
                    into v_aux_nro_archivo
                    from ge_pag_sueldos_err se
                   where se.cod_ente = v_cod_ente
                     and se.fec_proceso = v_fec_actual;
               exception
                  when others then
                     v_aux_nro_archivo := 1;
               end;
            end if;
         else
            v_aux_nro_archivo := pag_sue.fu_obt_sig_nro_secuencia(v_cod_ente, v_fec_actual);
         end if;
         
         if v_aux_nro_archivo > v_nro_archivo then
            v_nro_archivo := v_aux_nro_archivo;
         end if;
         --
         v_nro_archivo := v_nro_archivo + 1 ; */
         v_nro_archivo := fu_obt_nro_sec_sueldo(v_cod_ente, v_fec_actual);
     End if;
     -- obtenemos si el ente tiene traspaso de aguinaldo
     if p_tip_remuneracion = 'A' then
        v_traspaso := nvl(fug_obt_parentes(p_cod_ente, 'PAG_TRA_AGUINALDO'), 'N');
     end if;
     -- obtenemos la transacción padre
     if p_tip_remuneracion = 'S' then
       v_cod_tra_padre := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_SUELDO');
     elsif p_tip_remuneracion = 'A' then
       v_cod_tra_padre := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_AGUINALDO');
     elsif p_tip_remuneracion = 'C' then
       v_cod_tra_padre := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_COMISION');
     elsif p_tip_remuneracion = 'T' then
       v_cod_tra_padre := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_CREDITO');
     end if;
     ---
     v_lugar := 'leyendo los registros';
     v_det_temporal := null;
     for i in 1..p_can_registros
     loop
       v_registro         := substr(p_parametros,102 + ((i-1)*v_lon_registro), v_lon_registro);
       if p_modo <> 'V' THEN
         -- formato fijo
         -- CR: para verificar datos ingresados
         begin
           v_nro_cuenta := lf_obt_cta_limpia(substr(v_registro,1,15));
         exception
           when others then
             v_nro_cuenta := trim(substr(v_registro,1,15));
         end;
         v_monto      := nvl(to_number(replace(trim(substr(v_registro,16,16)),',','.')),0);
         v_tipo       := substr(v_registro,32,1);
       else
         -- formato segun archivo
         -- CR: para verificar datos ingresados
         begin
           v_nro_cuenta       := lf_obt_cta_limpia(fu_obt_dato(v_for_archivo,'GE_PAG_SUELDOS_TMP',v_registro,'NRO_CUENTA'));
         exception
           when others then
             null;
         end;
         v_monto            := fu_obt_dato(v_for_archivo,'GE_PAG_SUELDOS_TMP',v_registro,'MONTO');
         v_tipo             := fu_obt_dato(v_for_archivo,'GE_PAG_SUELDOS_TMP',v_registro,'TIPO');
       end if;
       -- OMM 07/10/2010
       if v_tipo is null or v_tipo not in ('C', 'D') then
          if v_nro_cuenta = v_nro_cta_debito then
             v_tipo := 'D';
          else
             v_tipo := 'C';
          end if;
       end if;
       if  v_tipo = 'C' then
         v_tot_detalles   := v_tot_detalles + v_monto;
         v_can_creditos   := v_can_creditos + 1 ;
       --  v_can_detalles   := v_can_detalles + 1; OMM 07/10/2010
       else
         v_nro_cta_debito := v_nro_cuenta ;
         v_can_cta_debito := v_can_cta_debito + 1; -- para validar que solo exista una cuenta débito
       end if;
       v_can_detalles   := v_can_detalles + 1;
       -- OMM 06/10/2010
       if  v_tipo in ('C','D') then
         -- valido la cuenta recibida
         begin
            v_cta_formateada := null;
            v_cod_tip_cuenta := null;
            v_des_tip_cuenta := null;
            v_nom_cuenta     := null;
            v_cod_moneda     := null;
            v_cod_modulo     := null;
            select fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina,a.nro_cuenta, a.cod_moneda) cta_formateada,
                   fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta,
                   fug_obt_des_modal(a.cod_modulo,a.cod_modalidad) des_tip_cuenta,
                   a.denominacion nom_cuenta, a.cod_moneda cod_moneda, a.cod_modulo
              into v_cta_formateada, v_cod_tip_cuenta, v_des_tip_cuenta, v_nom_cuenta, v_cod_moneda, v_cod_modulo
              from ge_est_cuentas c,ge_cuentas a
             where a.nro_cuenta = trim(v_nro_cuenta)
               and a.cod_modulo = c.cod_modulo
               and a.cod_modalidad = c.cod_modalidad
               and a.estado = c.estado
               and c.activo = 'S'  -- solo cuentas activas
               and a.estado not in ('X', 'C', 'P') -- se controla los estados cerrado y pend. de cancelación
               and a.cod_modalidad in (31,41); -- solo cuentas de ahorros y cuentas corrientes
            if p_cod_moneda <> v_cod_moneda then
               v_cod_res_cta := paw_bce.v_cod_cta_invalida;  -- moneda diferente
            else
               v_cod_res_cta := paw_bce.v_cod_aprobado;
            end if;
         exception
            when no_data_found then
               v_cod_res_cta := paw_bce.v_cod_cta_inexistente;
            when too_many_rows then
               v_cod_res_cta := paw_bce.v_cod_cta_duplicada;
            when others then
               v_cod_res_cta := paw_bce.v_cod_cta_invalida;
         end;
         if v_traspaso = 'S' and v_cod_res_cta = paw_bce.v_cod_aprobado AND v_tipo = 'C' THEN
            v_cod_error := 0;
            -- validamos cuentas de aguinaldo 
            pr_ver_cta_aguinaldo(v_nro_cuenta, v_traspaso, v_cod_error, v_mensaje, 40);
            if v_cod_error <> 0 then
               v_cod_res_cta := '-22';
            end if;
         END IF;
         if v_monto <= 0 and v_cod_res_cta = paw_bce.v_cod_aprobado then
            -- monto inválido
            v_cod_res_cta := paw_bce.v_cod_mto_invalido;
         end if;
         
         -- valido los decimales
         if v_cod_res_cta = paw_bce.v_cod_aprobado then
            if v_monto <> trunc(v_monto, v_redondeo) then
               v_cod_res_cta := paw_bce.v_mon_dec_invalida;
            end if;
         end if;
         -- verificamos si se puede realizar la operación de débito/crédito
         if v_cod_res_cta = paw_bce.v_cod_aprobado then
            -- obtenemos el codigo de transacción
            if v_tipo = 'D' then
              v_cod_transaccion := 503;
            else
              v_cod_transaccion := 602;
            end if;
         
            -- verificamos si se puede realizar la operación
            if fu_ver_operacion(v_nro_cuenta, v_monto, v_cod_transaccion, v_cod_tra_padre, v_tipo) = 'N' then
               if pag_cta.g_cod_error <> 0 then
                  -- controlamos si dispone de saldo suficiente
                  if pag_cta.g_cod_error in (25, 29, 31, 36) and v_tipo = 'D' then
                     v_cod_respuesta := paw_bce.v_cod_sal_insuficiente;
                  else
                     -- hubo otro error
                     v_cod_res_cta := paw_bce.v_cod_cta_invalida;
                  end if;
               end if;
            end if;
            -- verificamos el sobregiro
            if v_cod_res_cta = paw_bce.v_cod_aprobado and v_tipo = 'C' and v_cod_modulo = 4 and v_traspaso = 'S' then
               if (pag_cta.fu_sal_dis_combinada + pag_cta.FU_OBT_LIN_SOBREGIRO(v_nro_cuenta)) < 0 then
                  v_cod_res_cta := '-23';
               end if;
            end if;
         end if;
          -- armo el detalle por cuenta
          v_det_temporal :=  v_det_temporal ||
                        lf_for_char(v_nro_cuenta,17)||
                        --lf_for_char(v_cod_tip_cuenta,2)|| OMM 07/10/2010
                        lf_for_char(v_tipo,2)||
                        lf_for_char(v_des_tip_cuenta,35)||
                        lf_for_char(v_nom_cuenta,50)||
                        lf_for_char(rpad(v_cod_moneda,3,'.'),3)||
                        lf_for_money(v_monto,16)||
                        lf_for_char(v_cod_res_cta,3);
          -- es un traspaso temporal porque no se puede usar directamente un campo clob
          if (i / 78) = trunc(i / 78) then
             v_detalles := v_detalles ||v_det_temporal;
             v_det_temporal := null;
          end if;
          -- registro el codigo de respuesta general, si hay errores en el detalle
          if v_cod_respuesta = paw_bce.v_cod_aprobado then
             if v_cod_res_cta <> paw_bce.v_cod_aprobado then
                if v_tipo = 'D' then
                  if v_cod_res_cta = paw_bce.v_mon_dec_invalida then
                     v_cod_respuesta := paw_bce.v_cod_err_permitido; -- para que pueda editar el monto del débito importado
                   else
                      v_cod_respuesta := paw_bce.v_cod_cta_invalida;
                   end if;
                else
                  v_cod_respuesta := paw_bce.v_cod_err_permitido;
                end if;
             end if;
          end if;
          -- Es confirmacion y no hubo errores... OMM 07/10/2010
          If p_modo = 'C' and v_cod_respuesta = paw_bce.v_cod_aprobado then
             if v_tipo = 'D' then
                v_nro_cta_debito := v_nro_cuenta ;
             else
                 insert into ge_pag_sueldos_tmp
                   (cod_ente, nro_cuenta, fec_envio, tipo, monto, estado, nro_archivo)
                 values
                   (v_cod_ente, v_nro_cuenta, v_fec_actual, 'C', v_monto, 'H', v_nro_archivo);
              end if;
          End If;
        end if;
     end loop;
     v_lugar := 'Fin del ciclo Cantidad leidos: '||v_can_detalles;
   end if;
   
   -- no puede haber más de una cuenta débito
   if v_can_cta_debito > 1 then
      v_cod_respuesta := paw_bce.v_can_cta_deb_invalida;
   end if;
   --CR: se agrega control de máxima cantidad de registros para créditos.
   -- si se modifica esta cantidad, tambien se debe modificar itbank-lib.cgi
   if v_can_creditos > paw_bce.v_max_imp_archivo then
     v_cod_respuesta := paw_bce.v_can_cta_cre_excedida;  
   end if;   
   -- el último pedazo
   v_detalles := v_detalles ||v_det_temporal;
   
   if v_cod_respuesta = paw_bce.v_cod_aprobado then
      -- OMM 07/10/2010 Valida q la Cta debito sea de la empresa.
      if lf_cta_valida(v_nro_cta_debito,null) = 'N' then
          v_cod_respuesta :=  paw_bce.v_cod_cta_invalida ;
      end if ;
      if v_tot_detalles <> p_tot_debito then
         v_cod_respuesta := paw_bce.v_cod_tot_invalido;
      end if;
      IF v_can_creditos <> p_can_cuentas then
         v_cod_respuesta := paw_bce.v_cod_can_invalida;
      end if;
   end if;   
   If v_cod_respuesta != paw_bce.v_cod_aprobado then
      If p_modo = 'C' then -- Es confirmación y borra los temporales x errores...
         -- Al confirmar debe insertar en ge_pag_sueldos_tmp.
         v_lugar := 'borrando datos temporales';
         pag_sue.LP_DEL_DATOS_TEMPORA(v_cod_ente, v_fec_actual, v_lugar, v_nro_archivo);
      End if;
   Else
   IF p_modo = 'V' THEN
    -- OMM 19/07/2011 Verificación de Duplicacion
    DECLARE
       v_can_duplicado NUMBER(6) := 0;
                   --v_duplicado     VARCHAR2(1) := 'N';
    BEGIN
       SELECT COUNT(*)
       INTO v_can_duplicado
       FROM ge_pag_sueldos_tmp a
      WHERE a.cod_ente = v_cod_ente
        AND a.nro_cuenta = v_nro_cta_debito
        AND a.fec_envio = v_fec_actual
        AND a.tipo = 'D'
        AND a.monto = p_tot_debito
        AND a.estado = 'H'
        AND a.tip_remuneracion = p_tip_remuneracion
        AND a.nro_archivo IS NOT NULL;
       IF v_can_duplicado > 0 THEN
        v_cod_respuesta := paw_bce.v_cod_ped_duplicado;
       END IF;
    EXCEPTION
       WHEN OTHERS THEN
        NULL;
    END;
   END IF;
   -- 20/04/2012 : Verifico que la cta de débito tenga límite para la operación
   --              se agrega monitoreo de limite global de pago de salarios
   if v_cod_respuesta = paw_bce.v_cod_aprobado then
      if p_modo <> 'I' then
         v_res_limite := fu_obt_limite('070', 
                         nvl(v_cod_per_empresa,v_cod_persona), 
                         v_nro_cta_debito, 
                         p_cod_moneda, 
                         503, 
                         303,
                         p_tot_debito,
                         p_modo,
                         p_cod_ente );     
      end if;
   end if;
   -- 20/04/2012: se agrega mensaje de límite
   v_detalles := v_detalles ||v_res_limite;
   --   
   if v_cod_respuesta = paw_bce.v_cod_aprobado then
      if p_modo IN ('C', 'A') then
         v_ini_lim_param := 102 + (p_can_registros * v_lon_registro);
                
         if v_res_limite IN ('10', '11')  then -- clave transaccional requerida
            v_cod_respuesta := lf_obt_cla_validar(substr(p_parametros, v_ini_lim_param + 2),v_cod_persona,v_cod_per_empresa, 0, 'T');
         end if;
                
         if v_cod_respuesta = paw_bce.v_cod_aprobado then
            if v_res_limite IN ('01', '11') then -- token requerido
               v_cod_respuesta := fu_obt_tok_validar(substr(p_parametros, v_ini_lim_param + 34),v_cod_persona,v_cod_per_empresa, 0, p_modo);
            end if;
         end if;
      end if;
   end if;
   IF p_modo = 'C' AND v_cod_respuesta = paw_bce.v_cod_aprobado THEN
    -- Es confirmacion y no hubo errores...
     v_lugar := 'Insertando datos de sueldos';
     insert into ge_pag_sueldos_tmp
       (cod_ente, nro_cuenta, fec_envio, tipo, monto, estado, tip_remuneracion, nro_archivo)
     values
       (v_cod_ente, v_nro_cta_debito, v_fec_actual, 'D', p_tot_debito, 'H', p_tip_remuneracion, v_nro_archivo);
     -- Actualiza todos los registros con el tipo de Remuneración...
     update ge_pag_sueldos_tmp
      set tip_remuneracion = p_tip_remuneracion
      where cod_ente = v_cod_ente
      and fec_envio = v_fec_actual
      and fec_proceso is null
      and nro_archivo = v_nro_archivo;
      --
      if v_can_aut_requeridas > 0 then
      --- inserto el movimiento pendiente de autorizacion
      select s_nro_documento.nextval into v_nro_documento from dual;
      insert into bw_mov_pendientes
        (nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda,
         descripcion, monto, cantidad, etiqueta, dato, etiqueta2, dato2,
         estado,can_aut_requeridas, can_aut_faltantes, cod_per_ingreso, referencia)
      values
         (v_nro_documento,nvl(v_cod_per_empresa,v_cod_persona),sysdate,'070',v_nro_cta_debito,p_cod_moneda,
        'Pago de Salarios',p_tot_debito, v_can_creditos, 'Ente', p_cod_ente,
        'Tipo Pago', p_tip_remuneracion,
        'P', v_can_aut_requeridas, v_can_aut_requeridas, v_cod_persona, v_nro_archivo
         );
      else
      ----
        begin
          v_dir_correo := nvl(trim(fug_obt_pardinamico('SUE_DIR_CORREO')), fug_obt_pardinamico('CAM_MAR_PAG_NOM'));
        exception
          when others then
            v_dir_correo := fug_obt_pardinamico('CAM_MAR_PAG_NOM');
        end;
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
          v_lugar := 'Enviando mail';
          it_mail.mail(fug_obt_dir_correo,
                v_dir_correo,
                'Pago de Sueldos Pendiente',
                'Pago de Sueldos ingresado por HomeBanking pendientes '|| chr(10) ||
                'Codigo  : ' || v_cod_ente|| chr(10) ||
                'Empresa : ' || v_des_ente|| chr(10) ||
                'Monto   : ' || lf_for_money(p_tot_debito, 16)|| chr(10) ||
                'Cantidad: ' || to_char(v_can_creditos) || chr(10) ||
                'Atentamente. '
                );
         end if;
       end if;
     End if;
   End if;
   v_lugar := 'Registrando operacion';
   -- registro del movimiento
   lp_reg_operacion(v_nro_cta_debito /*p_nro_cuenta*/,
                    p_cod_moneda /*p_cod_moneda */,
                    p_tot_debito /*p_monto*/,
                    null /*p_nro_cta_contra*/,
                    v_can_creditos /*p_cantidad*/,
                    'Ente' /*p_etiqueta*/,
                    p_cod_ente /*p_dato*/
                    );
   -- siempre se responde con los detalles, sea o no sea con errores
   return lf_for_number(v_can_detalles,5)||lf_for_number(v_can_aut_requeridas,3)||
          (v_detalles);
exception
  when others then
     raise_application_error(-20005,sqlerrm||' En: '||v_lugar||' Cant.Reg '||v_can_detalles);
end; -- Pago de Sueldos

-- OMM 10/05/2011 Pago a Proveedores via Web
function fu_pro_operacion_075(p_parametros in clob)
  return clob is
-- datos recibidos
p_modo           varchar2(1)  := substr(p_parametros,66,1); -- modo de control C-CONFIRMA
p_cod_ente       number(5)    := to_number(substr(p_parametros,67,5));
v_fec_pago1      varchar2(10) := trim(substr(p_parametros, 72, 10));
v_fec_pago2      varchar2(10) := trim(substr(p_parametros, 82, 10));
p_can_orden      number(5)    := to_number(substr(p_parametros,92,5));
p_can_factura    number(5)    := to_number(substr(p_parametros,97,5));
v_registro       varchar2(4000);
v_lon_registro   number(5) := 412; --157; --117;
v_lon_reg_fac    number(5) := 43;
v_lon_reg_total  number(5) := 0;
-- CR: para poder pagar en otra moneda
v_arc_mon_local  varchar2(100);
v_arc_mon_fuerte varchar2(100);
--
v_for_archivo    varchar2(100);
--v_orden          ge_pag_proveedores_tmp.nro_orden%type;
-- datos de los detalles
--v_nro_cuenta     varchar2(17);      -- contiene los numeros de cuentas
--v_monto          number(18,2);      -- monto del credito
-- datos a responder
--v_tot_detalles   number(18,2) := 0; -- total a debitar
v_can_detalles   number(5)    := 0; -- cantidad de cuentas
--
v_detalles       clob := null; -- datos de las cuentas
---
v_cod_ente       number(6);         -- codigo del ente
v_des_ente       varchar2(100);     -- descripcion del ente
--v_formato        varchar2(30);      -- formato de archivo
--v_res_principal  varchar2(03) := '000'; -- respuesta
---
--v_nractiv        cr_agendas.cod_agenda%type;
v_indice         number(5);
v_tip_comprobante ge_pag_proveedores_tmp.tip_comprobante%type;
r_orden          ge_pag_proveedores_tmp%rowtype;
--r_factu          ge_pag_pro_facturas_tmp%rowtype;
v_nro_orden      ge_pag_pro_facturas_tmp.nro_orden%type;
v_nro_orden_fac  ge_pag_pro_facturas_tmp.nro_orden%type;
--v_tip_cobro      varchar2(1);
v_pos_ant        number(8);
v_pos_nvo        number(8);
v_nro_documento  number(20);
v_tot_debito     number(18,2);
v_cod_moneda     ge_cuentas.cod_moneda%type;
-- CR: para la cuenta débito del ente
v_cta_for_debito varchar2(17);
v_nom_cta_debito varchar2(100);
--
v_nro_cta_debito ge_cuentas.nro_cuenta%type;
v_for_fijo       varchar2(1) := 'S';
v_error          varchar2(2000);
p_fec_pago1      date;
p_fec_pago2      date;
v_concepto       varchar2(40);
v_tip_carga      varchar2(1):= 'A' ;
v_can_facturas   number(10):= 0 ;
v_err_pago     varchar2(2):= '00' ;
--CB 20/04/2012 Leer parametros de Cuenta y verificar decimales
v_cod_modulo     ge_movimientos.cod_modulo%type;
v_cod_modalidad  ge_movimientos.cod_modalidad %type;
v_cod_oficina    ge_movimientos.cod_oficina%type;
--v_estado         ge_cuentas.estado%type;
-- para control de límites
v_res_limite     varchar2(2);
v_ini_lim_param  number;
v_tra_pad_proveedor ge_movimientos.cod_tra_padre%type := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_PPROV');
v_tra_pad_credito ge_movimientos.cod_tra_padre%type := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_PRV_CREDITO');
v_cod_tra_padre  ge_movimientos.cod_tra_padre%type;
v_tip_pago       varchar2(1);  -- P: Pago a proveedores, C: Crédito en cuenta
v_des_pendiente  bw_mov_pendientes.descripcion%type;
v_can_ordenes    number;  -- cantidad de ordenes para crédito
v_dir_correo     ba_personas.dir_correo%type;
v_nro_archivo    ge_pag_proveedores_tmp.nro_archivo%type;
v_cam_fecha      boolean;
--

Cursor c_detalle(p_nro_archivo in number) is 
   Select nro_orden, nro_factura, tip_comprobante, for_pago, nro_cheque, nro_cta_credito,
                         fec_ingreso, fec_pago, monto, nro_recibo, beneficiario,
                         decode(cod_proceso, 0, 'Aprobado', InitCap(concepto)) concepto, estado,
                         cod_usu_operador, cod_ente, cod_proceso, cod_moneda,
                         tip_carga, nvl(f_cantidad, 0) f_cantidad, ref_facturas
             --doc_ret_cheque, nom_ret_cheque, suc_ret_cheque,
                         --nvl(endosable,'S') endosable, nvl(cruzado,'S') cruzado
                    from ge_pag_proveedores_tmp, (Select cod_ente f_cod_ente, nro_orden f_nro_orden, count(*) f_cantidad
                                                    from ge_pag_pro_facturas_tmp
                                                   where cod_ente = p_cod_ente
                                                     and trunc(fec_insercion) = trunc(sysdate)
                                                     and usu_insercion = user
                                                   Group by cod_ente, nro_orden)
                   where f_cod_ente(+) = cod_ente
                     and f_nro_orden(+) = nro_orden
                     and cod_ente = p_cod_ente
                     and usu_insercion = user
                     and tip_carga = 'H'
                     and nro_archivo = p_nro_archivo
                     and trunc(fec_insercion) = trunc(sysdate)
                     order by nro_orden;
Cursor c_det_fac is Select nro_orden, fec_carga, nro_factura,
                           mto_total, concepto, cod_ente
                      from ge_pag_pro_facturas_tmp
                     where cod_ente = p_cod_ente
                       and trunc(fec_insercion) = trunc(sysdate)
                       and nro_orden = v_nro_orden
             order by nro_factura;
cursor c_cuentas_proveedor IS
    Select distinct(trim(a.beneficiario)) beneficiario,
    (trim(decode(a.nro_cta_credito, '0',' ',null,' ',a.nro_cta_credito))) cta_credito,
    g.cod_moneda
    from ge_cuentas g,
         (Select distinct(trim(beneficiario)) beneficiario, max(trim(nro_cta_credito)) nro_cta_credito
          from ge_pag_proveedores
          where cod_ente = p_cod_ente
          and fec_proceso > sysdate - 90
          group by beneficiario
          union
          Select distinct(trim(beneficiario)) , max(trim(nro_cta_credito)) nro_cta_credito
          from ge_pag_proveedores_tmp
          where cod_ente = p_cod_ente
      group by beneficiario) a
    where g.nro_cuenta(+) = a.nro_cta_credito
      and nvl(g.estado,'A') in ('A','N','I')
      /*and not exists (select 0
         from bw_cta_accesos p
         where p.nro_cuenta = g.nro_cuenta
           and p.cod_per_vinculo = v_cod_persona
           and p.tip_acceso = 'P' ) */ ;

begin
   v_lugar := 'Validando clave';
   -- 1. valido la clave del cliente
   pr_val_clave(substr(p_parametros,1,100));
   v_lugar := 'Tomando las fechas';
   If v_fec_pago1 is not null then
      begin
        p_fec_pago1 := to_date(v_fec_pago1, 'DD/MM/YYYY');
      
        if p_fec_pago1 < v_fec_actual  then
          v_cod_respuesta := paw_bce.v_fec_invalida; -- se ajusta el mensaje de error
        end if;
      exception
        when others then
          v_cod_respuesta := paw_bce.v_fec_invalida;
      end;
   --else
     --v_fec_pago1  := null;
     --v_cod_respuesta := paw_bce.v_fec_invalida;
     
   End if;
   If v_fec_pago2 is not null then
     begin
       p_fec_pago2 := to_date(v_fec_pago2, 'DD/MM/YYYY');
       if p_fec_pago2 <= p_fec_pago1 then
         v_cod_respuesta := paw_bce.v_fec_invalida; -- se ajusta el mensaje de error
       end if;
     exception
       when others then
         v_cod_respuesta := paw_bce.v_fec_invalida;
     end;
   End if;
   ---
   v_lugar := 'Obteniendo permisos';
   -- Verifico si el cliente con su perfil tendrá acceso a realizar la transacción
   if v_cod_respuesta = paw_bce.v_cod_aprobado and nvl(p_modo,'x') <> 'A' then
     v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '075');
     if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
        v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
     end if;
   end if;
   -- 2. Verifico si la persona tiene el servicio de pago a proveedores
   if v_cod_respuesta = paw_bce.v_cod_aprobado then
     v_lugar := 'Datos del ente';
     begin
        -- se elimina cta_debito porque ahora se recibe en la mensajería,
        -- se agrega el formato de archivo para pagos en USD
        select a.cod_ente, a.descripcion,
               fug_obt_parentes(a.cod_ente,'TIP_COB_PPROV'),
               fug_obt_parentes(a.cod_ente,'REF_TXT_PPROV'),
               fug_obt_parentes(a.cod_ente,'REF_TXT_PPROV_USD')
          into v_cod_ente, v_des_ente, v_tip_comprobante,
               v_arc_mon_local, v_arc_mon_fuerte
          from ge_entes a
         where a.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
           and a.tipo = 'PR'
           and a.cod_ente = p_cod_ente
           and fug_obt_parentes(a.cod_ente,'SER_ACTIVO_PRV') = 'S'
           and fug_obt_parentes(a.cod_ente,'HAB_HOMEBANKING_PRV') = 'S';
        ---
        -- CR 03/09/2012 - La cuenta de débito ahora se recibe como parámetro en la mensajería
        -- validamos la misma y verificamos si pertenece al ente
        if p_modo in ('L', 'M') then
           v_nro_cta_debito := trim(substr(p_parametros, 102, 15));
           v_tip_pago       := trim(substr(p_parametros, 117, 1));
        elsif p_modo in ('C', 'V') then
           v_nro_cta_debito := trim(substr(p_parametros, 104, 15));
           v_tip_pago       := trim(substr(p_parametros, 119, 1));
        end if;
          
        if v_tip_pago = 'P' then              
           v_cod_tra_padre := v_tra_pad_proveedor; -- transacción padre para pago a proveedores
           v_des_pendiente := 'Proveedores';
        else              
           v_cod_tra_padre := v_tra_pad_credito; -- transacción padre para crédito en cuenta 
           v_des_pendiente := 'Crédito en Cuenta'; 
        end if;
           
        -- si no existe transacción padre, retornamos el error
        if v_cod_tra_padre is null then
           v_cod_respuesta := paw_bce.v_cod_tra_invalida;
        end if;
          
        -- validamos si la cuenta pertenece al cliente
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
           if lf_val_cta_origen(v_nro_cta_debito, nvl(v_cod_per_empresa,v_cod_persona)) = 'N' then
              -- no es una cuenta del cliente
              v_cod_respuesta := paw_bce.v_cod_cta_invalida;
           end if;
        end if;
        
    -- OMM 25/04/2011 Prueba de validacion comentada
        /*if v_tip_comprobante != 'O' and p_can_factura > 0 then
           v_cod_respuesta := paw_bce.v_cod_sin_factura;
        elsif v_tip_comprobante = 'O' and p_can_factura = 0 then
           v_cod_respuesta := paw_bce.v_cod_con_factura;
        end if;*/
        if p_modo <> 'M' then       
           select cod_moneda into v_cod_moneda
             from ge_cuentas
            where nro_cuenta = v_nro_cta_debito;
        
           -- CR: de acuerdo a la moneda, se elige el formato de archivo
           if v_cod_moneda = paw_bce.v_cod_mon_local then
              v_for_archivo := v_arc_mon_local;
           elsif v_cod_moneda = pag_gen.FU_OBT_MON_FUERTE then
              v_for_archivo := v_arc_mon_fuerte;
           else
              v_cod_respuesta := paw_bce.v_cod_tra_invalida;
           end if;
           
           -- CR: Si no tiene definido el formato de importación
           -- para archivos, debe dar error
           if v_for_archivo is null and p_modo = 'L' then
             v_cod_respuesta := paw_bce.v_fmt_arc_indefinido;
           end if;
        end if;
     exception
        when no_data_found then
           v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
        when too_many_rows then
           v_cod_respuesta := paw_bce.v_cod_cta_duplicada;
        when others then
            v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
     end;
   end if;
   /*-- 3. Verifico que no exista un pago pendiente de aprobación   
   if v_cod_respuesta = paw_bce.v_cod_aprobado then
     if nvl(p_modo, 'x') <> 'A' then     
       declare
         v_existe varchar2(1) := 'N';
       begin
         begin
           select 'S'
             into v_existe
             from bw_mov_pendientes
            where cod_per_principal = nvl(v_cod_per_empresa,v_cod_persona)              
              and estado = 'P'
              and cod_tip_mensaje = '075'
              and dato = trim(to_char(p_cod_ente))
              and trunc(fec_insercion) = trunc(sysdate)
              and rownum = 1;              
         exception
           when too_many_rows then
             v_existe := 'S';
           when others then
             v_existe := 'N';
         end;
       
         if v_existe = 'S' then
           v_cod_respuesta := paw_bce.v_cod_pag_pendiente;
         end if;
       end;
     end if;
   end if;*/
   if p_modo = 'M' THEN
      for reg in c_cuentas_proveedor LOOP
          v_can_detalles := v_can_detalles + 1;
          -- armo el detalle de las cuentas a acreditar
          v_detalles :=  v_detalles ||
                        lf_for_char(reg.beneficiario,50)||
                        lf_for_char(reg.cta_credito,17)||
                        lf_for_char(reg.cod_moneda,3);
      end loop;
   else
     -- 4. Tomo la cantidad de cuentas recibidas
     if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- CR 03/09/2012 se comenta la eliminación de movimientos pendientes,
     -- se valida con anterioridad que no exista un pago pendiente de aprobación
     -- y no deja continuar en tal caso
     /* 
     -- borro el mov pendiente si existe
     v_lugar := 'Borrando pendientes';
     delete from bw_mov_pendientes
      where cod_tip_mensaje = '075'
      and estado = 'P'
      and trunc(fec_hora) = trunc(sysdate)
      and dato = trim(to_char(p_cod_ente))
      and cod_per_principal = nvl(v_cod_per_empresa,v_cod_persona); */
     --- lee las ordenes de pago
     --v_lugar := 'Borrando pendientes 2';
     --pag_prv.PR_ELI_PROV_TMP(p_cod_ente, p_fec_pago1, v_nro_archivo);
     --v_lugar := 'Borrando pendientes 3';
     --pag_prv.PR_ELI_FAC_TMP(p_cod_ente, p_fec_pago1, v_nro_archivo);
     v_indice := 1;
     v_tip_comprobante := fug_obt_parentes(p_cod_ente, 'TIP_COB_PPROV');
     v_for_fijo := 'S';
     if instr(p_parametros,'~') > 0 then
        v_for_fijo := 'N';
     end if;
     v_pos_ant := 118; -- 104, se modifica porque cambia la mensajería, se agrega cta_debito y tip_pago
     v_tot_debito := 0;
     v_cam_fecha := fu_ver_hor_cie_proveedor(p_fec_pago1);
     v_nro_archivo := pag_prv.fu_obt_nro_secuencia(p_cod_ente, p_fec_pago1);
     If p_can_orden > 0 then
       v_can_ordenes := 0; -- para contar el total de créditos, no puede super paw_bce.v_max_imp_archivo
       -- CR 03/09/2012 se eliminó control de valor decimal
       -- ya que la misma se hace en pag_prv.pr_ver_dat_tmp 
       for i in 1..p_can_orden loop
          ----
          v_lugar := 'Leyendo el registro Nro.'||i;
          if v_for_fijo = 'S' then
            -- formato fijo
            v_registro := substr(p_parametros,120 + ((i-1)*v_lon_registro), v_lon_registro);
            v_indice := 1;
            r_orden := null;
            -- CR: se agrega validación de dato ingresado
            begin
              r_orden.nro_orden := to_number(substr(v_registro, v_indice, 10)); 
            exception
              when others then
                r_orden.nro_orden := i;
            end;
            v_indice := v_indice + 10;
            r_orden.nro_factura := trim(substr(v_registro, v_indice, 15)); v_indice := v_indice + 15;
            r_orden.tip_comprobante := v_tip_comprobante; -- Toma del parametro del Ente....
            r_orden.for_pago := trim(substr(v_registro, v_indice, 1)); v_indice := v_indice + 1;
            r_orden.nro_cheque := null;
            r_orden.nro_cta_credito := trim(substr(v_registro, v_indice, 15)); v_indice := v_indice + 15;
            r_orden.fec_ingreso := v_fec_actual;
            r_orden.fec_pago := null;
            r_orden.monto := to_number(substr(v_registro, v_indice, 18)); v_indice := v_indice + 18;
            r_orden.nro_recibo := null;
            r_orden.beneficiario := trim(substr(v_registro, v_indice, 50)); v_indice := v_indice + 50;
            r_orden.concepto := null;
            r_orden.estado := 'C';
            r_orden.cod_usu_operador := user;
            r_orden.cod_ente := p_cod_ente;
            r_orden.cod_proceso := null;
            r_orden.cod_moneda := trim(substr(v_registro, v_indice, 3)); v_indice := v_indice + 3;
            -- OMM 25/04/2011 Ajuste para
            If p_can_factura > 0 then
               v_tip_carga := 'M' ;
               v_lon_reg_total := (120 + (p_can_orden)*v_lon_registro) ;
               r_orden.ref_facturas := null ;
               for n in 1..p_can_factura loop
                  v_indice := 1;
                  v_registro         := substr(p_parametros,v_lon_reg_total + ((n-1)*v_lon_reg_fac), v_lon_reg_fac);
                  -- CR: se valida lo ingresado por el usuario
                  begin
                    v_nro_orden_fac := to_number(substr(v_registro, v_indice, 10));
                  exception
                    when others then
                      v_nro_orden_fac := r_orden.nro_orden;
                  end;
                   v_indice := v_indice + 10;
                  --
                  if v_nro_orden_fac = r_orden.nro_orden then
                      v_can_facturas := v_can_facturas + 1 ;
                      r_orden.ref_facturas  := r_orden.ref_facturas || trim(substr(v_registro, v_indice, 15)) ||';';
                      if trim(r_orden.nro_factura) is null and v_can_facturas = 1 then
                         r_orden.nro_factura := trim(substr(v_registro, v_indice, 15)) ;
                      end if ;
                  end if ;
                      v_indice := v_indice + 33 ;
               end loop;
               v_can_facturas := 0 ;
            else
               r_orden.ref_facturas  := trim(substr(v_registro, v_indice, 300)); v_indice := v_indice + 300;   
            end if ;
            -- CR 03/09/2012 se eliminó control de valor decimal
            -- ya que la misma se hace en pag_prv.pr_ver_dat_tmp 
      /*r_orden.doc_ret_cheque := trim(substr(v_registro, v_indice, 10)); v_indice := v_indice + 10;
            r_orden.nom_ret_cheque := trim(substr(v_registro, v_indice, 30)); v_indice := v_indice + 30;
            r_orden.suc_ret_cheque := trim(substr(v_registro, v_indice, 3)); v_indice := v_indice + 3;
             -- agregado  endosable y cruzado
            r_orden.endosable := trim(substr(v_registro, v_indice, 1)); v_indice := v_indice + 1;
            r_orden.cruzado := trim(substr(v_registro, v_indice, 1)); v_indice := v_indice + 1; */
            r_orden.tip_carga := 'H';
            r_orden.nro_archivo := v_nro_archivo;
          else
            v_lugar := 'Tomo el registro ';
            v_pos_nvo   := instr(p_parametros,'~',118,i);
            v_registro  := substr(p_parametros,v_pos_ant, v_pos_nvo - v_pos_ant);
            v_pos_ant   := v_pos_nvo + 1;

            -- tomo los datos segun formato de archivo
            r_orden                  := null;
            r_orden.cod_ente         := p_cod_ente;
            v_lugar := 'Nro de orden';
            r_orden.nro_orden        := NVL(fu_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'NRO_ORDEN'),i);
            v_lugar := 'Nro de Factura';
            r_orden.nro_factura      := fu_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'NRO_FACTURA');
            v_lugar := 'Forma de pago';
            r_orden.for_pago         := fu_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'FOR_PAGO');
            if r_orden.for_pago is null then
               r_orden.for_pago := 'C' ;
            end if ;
            v_lugar := 'Nro de cta credito';
            r_orden.nro_cta_credito  := fu_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'NRO_CTA_CREDITO');
            v_lugar := 'Fecha de pago';
            r_orden.fec_pago         := to_date(fu_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'FEC_PAGO'),'dd/mm/yyyy');
            v_lugar := 'monto';
            r_orden.monto            := fu_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'MONTO');
            v_lugar := 'Beneficiario';
            r_orden.beneficiario     := fu_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'BENEFICIARIO');
            v_lugar := 'Moneda';
            r_orden.cod_moneda       := fu_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'COD_MONEDA');
            v_lugar := 'Ref_factura';
            r_orden.ref_facturas      := fu_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'REF_FACTURAS');
                /*v_lugar := 'Pers quien retira ';
                r_orden.nom_ret_cheque   := lf_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'NOM_RET_CHEQUE');
                v_lugar := 'Doc. de la pers   ';
                r_orden.doc_ret_cheque   := lf_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'DOC_RET_CHEQUE');
                v_lugar := 'Suc del cheque ';
                r_orden.suc_ret_cheque   := lf_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'SUC_RET_CHEQUE');
                -- agregado  endosable y cruzado
                r_orden.endosable   := lf_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'ENDOSABLE');
                r_orden.cruzado     := lf_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'CRUZADO');
                -- se agrego para control de datos. Debe coincidir Ref de archivo con Param.Enter NRO_REF_CLIENTE
                r_orden.nro_ref_cliente   := lf_obt_dato(v_for_archivo,'GE_PAG_PROVEEDORES_TMP',v_registro,'NRO_REF_CLIENTE');
                 */
            r_orden.concepto         := null;
            r_orden.estado           := 'C';
            r_orden.tip_carga        := 'H';
            r_orden.nro_archivo    := v_nro_archivo;
            r_orden.cod_usu_operador := user;
            r_orden.nro_cheque       := null;
            r_orden.tip_comprobante  := v_tip_comprobante; -- Toma del parametro del Ente....
            r_orden.fec_ingreso      := v_fec_actual;
            -- CR 03/09/2012 se eliminó control de valor decimal
            -- ya que la misma se hace en pag_prv.pr_ver_dat_tmp           
          end if;
          if r_orden.nro_factura is null then
             r_orden.nro_factura := r_orden.nro_orden;
          end if;
          -- CR aumentamos el contador de créditos
          v_can_ordenes := v_can_ordenes + 1;
          -- CR 03/09/2012 se sumariza solo si el monto es válido
          if r_orden.monto > 0 then
             v_tot_debito := v_tot_debito + r_orden.monto;
          end if;
          ----
          v_lugar := 'Insertando en temporales';
          if r_orden.for_pago in ('C','G') then
              insert into ge_pag_proveedores_tmp
              (nro_orden, nro_factura, tip_comprobante, for_pago, nro_cheque,
               nro_cta_credito, fec_ingreso, fec_pago, monto, nro_recibo,
               beneficiario, concepto, estado, cod_usu_operador,
               cod_ente, cod_proceso, cod_moneda, tip_carga, nro_archivo, ref_facturas)
      --,doc_ret_cheque, nom_ret_cheque, suc_ret_cheque,orden, endosable, cruzado)
              values
              (r_orden.nro_orden, r_orden.nro_factura, r_orden.tip_comprobante, r_orden.for_pago, r_orden.nro_cheque,
               r_orden.nro_cta_credito, r_orden.fec_ingreso, r_orden.fec_pago, r_orden.monto, r_orden.nro_recibo,
               r_orden.beneficiario, r_orden.concepto, r_orden.estado, r_orden.cod_usu_operador,
               r_orden.cod_ente, r_orden.cod_proceso, r_orden.cod_moneda, r_orden.tip_carga, r_orden.nro_archivo, r_orden.ref_facturas);
               --,r_orden.doc_ret_cheque, r_orden.nom_ret_cheque, r_orden.suc_ret_cheque,v_orden,
                --    r_orden.endosable, r_orden.cruzado);
           end if;
       end loop;
       -- 03/05/2012: para límite de operaciones
       v_ini_lim_param := 120 + p_can_orden*v_lon_registro;
       
       -- fin límites
       --- lee las facturas
       If p_can_factura > 0 then
         v_lon_registro := 100;
        --for i in 1..p_can_factura loop
            --v_indice := 1;

            --v_registro         := substr(p_parametros,104 + ((i-1)*v_lon_registro), v_lon_registro);
            -- Leo las facturas....
          /*  r_factu.nro_orden   := to_number(substr(v_registro, v_indice, 10)); v_indice := v_indice + 10;
            r_factu.nro_factura := trim(substr(v_registro, v_indice, 10)); v_indice := v_indice + 10;
            r_factu.mto_total   := to_number(substr(v_registro, v_indice, 18)); v_indice := v_indice + 18;
            r_factu.concepto    := trim(substr(v_registro, v_indice, 35)); v_indice := v_indice + 35;
            r_factu.cod_ente    := p_cod_ente;
            r_factu.fec_carga   := null; */
            --insert into ge_pag_pro_facturas_tmp
            --    (nro_orden, fec_carga, nro_factura, mto_total, concepto, cod_ente)
            --values
            --    (r_factu.nro_orden, r_factu.fec_carga, r_factu.nro_factura, r_factu.mto_total, r_factu.concepto, r_factu.cod_ente);
         --end loop;
       End if;
       -- CR: se controla que el total de créditos no supere el máximo permitido
       v_lugar := 'Validando el total de creditos';
       if v_can_ordenes > paw_bce.v_max_imp_archivo then
         v_cod_respuesta := paw_bce.v_can_cta_cre_excedida;
       end if;
       -- CR: se valida la cuenta de débito
       v_lugar := 'Validando la cuenta del cliente';
       if v_cod_respuesta = paw_bce.v_cod_aprobado then
          pr_val_cta_debito(v_nro_cta_debito,
                            v_cod_tra_padre,
                            v_tot_debito,
                            v_cod_moneda,
                            v_cod_modulo,
                            v_cod_modalidad,
                            v_cod_oficina,
                            v_cta_for_debito,
                            v_nom_cta_debito);
          if v_cod_respuesta <> paw_bce.v_cod_aprobado then
            -- para poder corregir los decimales en los detalles  
            if instr(pag_cta.G_MSJ_ERROR, 'Decimales no permitidos') > 0 then
              v_cod_respuesta := paw_bce.v_cod_err_permitido /*'-88'*/;
            end if;
          end if;
       end if;
       if v_cod_respuesta = paw_bce.v_cod_aprobado or v_cod_respuesta = paw_bce.v_cod_err_permitido /*'-88'*/ then
          v_lugar := 'Verificando datos temporales';
          --- Una vez que carga todo va a validar....
          pag_prv.PR_VER_DAT_TMP(p_cod_ente, p_fec_pago1, p_fec_pago2, v_error, 'N', null, v_nro_cta_debito, v_nro_archivo);
          If v_error is not null and v_cod_respuesta = paw_bce.v_cod_aprobado then
             v_cod_respuesta := paw_bce.v_cod_err_permitido /*'-88'*/; -- hay problemas en algun dato
          End if;
          v_detalles := null;
          v_can_detalles := p_can_orden;
          v_lugar := 'Generando salida';
          For r1 in c_detalle(v_nro_archivo) Loop
             -- CR 03/09/2012 se eliminó control de valor decimal
             -- ya que la misma se hace en pag_prv.pr_ver_dat_tmp
          
             -- CR 03/09/2012, se eliminó control de moneda local 
             -- ya que se puede pagar en USD          
             v_detalles := v_detalles ||
                lf_for_number(r1.nro_orden, 10)||
                lf_for_char(r1.nro_factura, 15)||
                r1.for_pago||
                lf_for_char(nvl(r1.nro_cta_credito,' '),15)||
                lf_for_money(r1.monto, 18)||
                lf_for_char(nvl(r1.beneficiario,' '), 50)||
                lf_for_char(nvl(r1.cod_moneda, ' '), 3)||
                lf_for_char(nvl(v_concepto,r1.concepto), 40)||
                lf_for_number(r1.cod_proceso, 3)||
                --lf_for_number(v_can_facturas, 3) ||
                lf_for_number(r1.f_cantidad, 3) ||
                lf_for_char(r1.ref_facturas, 300);
                --lf_for_char(r1.doc_ret_cheque, 10)||
                --lf_for_char(r1.nom_ret_cheque, 30)||
                --lf_for_number(r1.suc_ret_cheque, 3)||
                --lf_for_char(r1.endosable, 1)||
                --lf_for_char(r1.cruzado, 1);
                -- OMM 12/04/2011 Se agrega un espacion de 45 al final para emular lo comentado arriba
                --lf_for_char(' ', 45) ;
             -- Por cada factura lee el detalle de las facturas si es que posee...
             v_nro_orden := r1.nro_orden;
             If r1.f_cantidad > 0 then
                For r2 in c_det_fac Loop
                   v_detalles := v_detalles||
                lf_for_number(r2.nro_orden, 10)||
                      lf_for_char(nvl(r2.nro_factura, ' '), 15)||
                      lf_for_money(nvl(r2.mto_total,0), 18)||
                      lf_for_char(nvl(r2.concepto, ' '), 35);
                End Loop;
             End if;
          End Loop;
       end if;     
       -- 03/05/2012 : Verifico que la cta de débito tenga límite para la operación
       -- se agrega monitoreo de límite global de pago a proveedores        
       if v_cod_respuesta = paw_bce.v_cod_aprobado then
          if p_modo <> 'I' then
             v_lugar := 'Verificando limites';          
             v_res_limite := fu_obt_limite('075', 
                         nvl(v_cod_per_empresa,v_cod_persona), 
                         v_nro_cta_debito, 
                         v_cod_moneda, 
                         503, 
                         v_cod_tra_padre, 
                         v_tot_debito,
                         p_modo,
                         p_cod_ente );     
          end if;
       end if;
   
       v_detalles := v_detalles || lf_for_char(v_res_limite,2);
       v_lugar := 'Verificando claves';
       if v_cod_respuesta = paw_bce.v_cod_aprobado then
          if p_modo IN ('C', 'A') then
             v_ini_lim_param := v_ini_lim_param + p_can_factura*v_lon_reg_fac;
                
             if v_res_limite IN ('10', '11')  then -- clave transaccional requerida
                v_cod_respuesta := lf_obt_cla_validar(substr(p_parametros, v_ini_lim_param + 2, 150),v_cod_persona,v_cod_per_empresa, 0,'T');
             end if;
                
             if v_cod_respuesta = paw_bce.v_cod_aprobado then
                if v_res_limite IN ('01', '11') then -- token requerido
                   v_cod_respuesta := fu_obt_tok_validar(substr(p_parametros, v_ini_lim_param + 34, 150),v_cod_persona,v_cod_per_empresa, 0, p_modo);
                end if;
             end if;
          end if;
       end if;
       -- 
       ---
       if p_modo <> 'C' or v_cod_respuesta <> paw_bce.v_cod_aprobado then
         v_lugar := 'Borrando pendientes 2';
         pag_prv.PR_ELI_PROV_TMP(p_cod_ente, sysdate, v_nro_archivo);
         v_lugar := 'Borrando pendientes 3';
         pag_prv.PR_ELI_FAC_TMP(p_cod_ente, sysdate, v_nro_archivo);
       end if;
       If v_cod_respuesta = paw_bce.v_cod_aprobado and p_modo = 'C' then
          /*-- CR verifico la hora de cierre 
          v_lugar := 'Verificando fecha de pago';
          if v_can_aut_requeridas = 0 then
            declare
              v_cam_fecha boolean;
            begin
              v_cam_fecha := fu_ver_hor_cie_proveedor(p_fec_pago1);   
            end;
          end if;*/
          --
          if v_can_aut_requeridas > 0 then
            v_lugar := 'Insertando mov pendiente';
            --- inserto el movimiento pendiente de autorización
            select s_nro_documento.nextval into v_nro_documento from dual;
            insert into bw_mov_pendientes
              (nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda,
               descripcion, monto, cantidad, etiqueta, dato, etiqueta2, dato2,
               estado,can_aut_requeridas, can_aut_faltantes, cod_per_ingreso, referencia, tip_pago)
            values
               (v_nro_documento,nvl(v_cod_per_empresa,v_cod_persona),sysdate,'075',v_nro_cta_debito,v_cod_moneda,
                v_des_pendiente,v_tot_debito, p_can_orden, 'Ente', p_cod_ente,
                'Fechas de Pago',to_char(p_fec_pago1,'dd/mm/yyyy')||' '||to_char(p_fec_pago2,'dd/mm/yyyy'),
                'P', v_can_aut_requeridas, v_can_aut_requeridas, v_cod_persona, v_nro_archivo, v_tip_pago);
          else
              /* OMM 03/05/2011 Se inserta como movimiento pendiente solo para agrupar 
                 para el procedimiento de generacion de movimientos*/
              select s_nro_documento.nextval into v_nro_documento from dual;
              insert into bw_mov_pendientes
                (nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda,
                 descripcion, monto, cantidad, etiqueta, dato, etiqueta2, dato2,
                 estado,can_aut_requeridas, can_aut_faltantes, cod_per_ingreso, referencia, tip_pago)
              values
                 (v_nro_documento,nvl(v_cod_per_empresa,v_cod_persona),sysdate,'075',v_nro_cta_debito,v_cod_moneda,
                  v_des_pendiente,v_tot_debito, p_can_orden, 'Ente', p_cod_ente,
                  'Fechas de Pago',to_char(p_fec_pago1,'dd/mm/yyyy')||' '||to_char(p_fec_pago2,'dd/mm/yyyy'),
                  'C', 0, 0, v_cod_persona, v_nro_archivo, v_tip_pago);

              pag_prv.PR_VER_DAT_TMP(p_cod_ente, p_fec_pago1, p_fec_pago2, v_error, 'S', v_nro_documento, v_nro_cta_debito, v_nro_archivo);

              if v_error is not null then
                 --- raise_application_error(-20000,v_error);
                 v_cod_respuesta := v_err_pag_prov;
              else
                 -- OMM 02/05/2011 Se generan los movimientos automáticamente
                 if to_char(p_fec_pago1,'DD/MM/YYYY') = trunc(sysdate) then
                    pag_prv.PR_PRO_PAGO(p_cod_ente, v_nro_documento, v_err_pago) ;
                    if v_err_pago <> '00' then
                       v_cod_respuesta := v_err_pag_prov ;
                    else    
                       it_mail.mail( fug_obt_dir_correo,
                                fug_obt_pardinamico('CAM_MAR_PAG_NOM'),
                                'Pago a Proveedores en Linea',
                                'Pago a Proveedores ingresado por el HomeBanking '|| chr(10) ||chr(10) ||
                                'Codigo  : ' || p_cod_ente|| chr(10) ||
                                'Empresa : ' || v_des_ente|| chr(10) ||
                                'Monto   : ' || to_char(v_tot_debito,'999G999G999G999D99')||' '||v_cod_moneda||chr(10)||
                                'Cantidad: ' || to_char(p_can_orden) || chr(10) ||
                                'Fecha de Pago: ' || to_char(p_fec_pago1) || chr(10) ||chr(10) ||
                                'Atentamente. '
                                );
                    end if ;
                 else
                    it_mail.mail( fug_obt_dir_correo,
                                fug_obt_pardinamico('CAM_MAR_PAG_NOM'),
                                'Pago a Proveedores Fecha Futura',
                                'Pago a Proveedores ingresado por el HomeBanking '|| chr(10) ||chr(10) ||
                                'Codigo  : ' || p_cod_ente|| chr(10) ||
                                'Empresa : ' || v_des_ente|| chr(10) ||
                                'Monto   : ' || to_char(v_tot_debito,'999G999G999G999D99')||' '||v_cod_moneda||chr(10)||
                                'Cantidad: ' || to_char(p_can_orden) || chr(10) ||
                                'Fecha de Pago: ' || to_char(p_fec_pago1) || chr(10) ||chr(10) ||
                                'Atentamente. '
                                );
                 end if;
              End if;
          end if;
          
          v_lugar := 'Enviando correo incorrecto';
          -- si hubieron registros eliminados por el usuario se envía para conocimiento del ente
          if (v_error is null and length(p_parametros) > (v_ini_lim_param + (2 + 32 + paw_bce.v_max_lon_otp))) then
             -- obtenemos la direccion de correo de la empresa
             begin
               v_dir_correo := fug_obt_dir_mail_per(v_cod_per_empresa);
             exception
               when others then
                 v_dir_correo := fug_obt_pardinamico('CAM_MAR_PAG_NOM');
             end;
             it_mail.mail_attach( fug_obt_dir_correo,
                           v_dir_correo,
                           'Pago a Proveedores - Registros No Procesados',
                           'Pago a Proveedores ingresado por el HomeBanking '|| chr(10) ||chr(10) ||
                           'Codigo  : ' || p_cod_ente|| chr(10) ||
                           'Empresa : ' || v_des_ente|| chr(10) ||
                           'Moneda  : ' || v_cod_moneda || chr(10) ||
                           'Fecha de Pago: ' || to_char(p_fec_pago1) || chr(10) ||chr(10) ||
                           'Se envia adjunto los registros no acreditados'|| chr(10) ||chr(10) ||
                           'Atentamente. ',
                           RPAD('CUENTA',15)||
                           RPAD('BENEFICIARIO',50)||
                           RPAD('MONTO',18)||
                           RPAD('MOTIVO',40)||chr(13)||chr(10)||
                           RPAD('-',123,'-')||
                           replace(substr(p_parametros, v_ini_lim_param + (2 + 32 + paw_bce.v_max_lon_otp)),'*',chr(13)||chr(10)),
                           p_cod_ente||'_'||v_cod_moneda||'_reg_eli_'||to_char(sysdate,'yyyymmddhh24miss')||'.txt'
                           ); 
          end if;
       End if;
     else
       v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
     end if;

    end if;
   end if ;
   v_lugar := 'Registrando log';
   -- registro del movimiento
   lp_reg_operacion(null,        --p_nro_cuenta
                    null,        --p_cod_moneda
                    null,        --p_monto
                    null,        --p_nro_cta_contra
                    p_can_orden, --p_cantidad
                    'Ente',      --p_etiqueta
                    p_cod_ente,  --p_dato
                    'Fecha',     --p_etiqueta2
                    to_char(p_fec_pago1,'dd/mm/yyyy'), --p_dato2
                    null,        --Observacion*/,
                    null,        --Direccion IP
                    substr(p_parametros,1,1000));
   -- siempre se responde con los detalles, sea o no sea con errores
   return lf_for_number(v_can_detalles,4)||lf_for_number(v_can_aut_requeridas,2)||
          v_detalles;
exception
  when others then
      -- registro del movimiento (LOG)
    lp_reg_operacion(null,        --p_nro_cuenta
                    null,        --p_cod_moneda
                    null,        --p_monto
                    null,        --p_nro_cta_contra
                    p_can_orden, --p_cantidad
                    'Ente',      --p_etiqueta
                    p_cod_ente,  --p_dato
                    'Fecha',     --p_etiqueta2
                    to_char(p_fec_pago1,'dd/mm/yyyy'), --p_dato2
                    sqlerrm,        --Observacion,
                    null,        --Direccion IP
                    substr(p_parametros,1,1000));  --Mensaje
    --
    if sqlcode <= -20000 then
       raise;
    else
       if v_cod_respuesta = '000' then
          if v_for_fijo = 'N' then
             v_cod_respuesta := paw_bce.v_cod_dat_invalido; -- problema con el archivo
          else
             v_cod_respuesta := paw_bce.v_cod_otr_error;
          end if;
       end if;
         raise_application_error(-20005,sqlerrm||' En: '||v_lugar||' Cant.Reg '||v_can_detalles);
        --raise_application_error(-20005,sqlerrm);
    end if;
  return null;
end; -- Pago a Proveedores.


-- cambio de clave del cliente
function fu_pro_operacion_080(p_parametros in varchar2)
  return varchar2 is
-- datos recibidos
v_cla_nueva varchar2(32) := substr(p_parametros,66,32); -- nueva clave
v_clave     varchar2(300);
v_aux       varchar2(100);
begin
   -- 1. valido la clave del cliente
   pr_val_clave(p_parametros);
   
   -- 2. Control de la clave nueva
   if v_cod_respuesta = paw_bce.v_cod_aprobado then   
     if length(trim(v_cla_nueva)) = 0 then
       -- no viene la clave nueva
       v_cod_respuesta := paw_bce.v_cod_pin_invalido;
     elsif v_cla_nueva = p_clave then
       -- clave igual a la anterior
       v_cod_respuesta := paw_bce.v_cod_pin_invalido;
     else
       -- aprobado
       v_cod_respuesta := paw_bce.v_cod_aprobado;
       
       -- actualizo la nueva clave
       v_clave := fu_gen_ope_clave(v_cla_nueva, v_cod_persona, v_cod_per_empresa, 'A', 'A', v_aux);
       if v_clave in ('-5', '-3') then
         v_cod_respuesta := paw_bce.v_cod_pin_invalido;
       elsif v_clave = '-6' then
         v_cod_respuesta := paw_bce.v_sol_cla_existe;
       end if;       
     end if;
   end if;
   -- registro del movimiento
   lp_reg_operacion(null /*p_nro_cuenta*/,
                    null /*p_cod_moneda */,
                    null /*p_monto*/,
                    null /*p_nro_cta_contra*/,
                    null /*p_cantidad*/,
                    'Clave Nueva' /*p_etiqueta*/,
                    'Acceso' /*p_dato*/
                    );
   return ' ';  -- nada
end;
-- fin del cambio de clave
-- Mensaje a la entidad
function fu_pro_operacion_081(p_parametros in varchar2)
  return varchar2 is
-- datos recibidos
v_nro_sobre varchar2(10) := substr(p_parametros,66,10); -- sobre del mensaje
--
begin
   -- 1. valido la clave del cliente
   pr_val_clave(p_parametros);
   -- 2. aprobado, se genera un movimiento
   if  v_cod_respuesta = paw_bce.v_cod_aprobado then
       -- genero un movimiento de mensajes al banco
      r_gmovi.cod_modulo      := 9;
      r_gmovi.cod_modalidad   := 91;
      r_gmovi.cod_oficina     := v_cod_ofi_origen;
      r_gmovi.nro_cuenta      := null;
      r_gmovi.cod_moneda      := v_cod_mon_local;
      r_gmovi.cod_usuario     := v_cod_usuario;
      -- aumento la secuencia
      r_gmovi.nro_secuencia   := 1;
      --
      r_gmovi.hora            := v_hor_actual;
      r_gmovi.fecha           := v_fec_actual;
      r_gmovi.fec_valor       := v_fec_valor;
      r_gmovi.cod_mod_padre   := 9;
      r_gmovi.cod_mad_padre   := 91;
      r_gmovi.cod_tra_padre   := 392;
      r_gmovi.cod_transaccion := 392;
      r_gmovi.monto           := null;
      r_gmovi.nro_documento   := v_nro_sobre;
      r_gmovi.nro_documento2  := nvl(v_cod_per_empresa,v_cod_persona);
      r_gmovi.cod_tasa        := null;
      r_gmovi.val_tasa        := null;
      r_gmovi.cotizacion      := null;
      r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        :=  'Mensaje del cliente';
      r_gmovi.est_cuenta      := null;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.nro_caja        := paw_bce.v_nro_terminal;
      -- genero el movimiento por cambio de estado
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
   end if;
   -- registro del movimiento
   lp_reg_operacion;
   return ' ';  -- nada
end;
-- fin del mensaje a la entidad

-- Pago de Servicios
function fu_pro_operacion_082(p_parametros in varchar2)
  return varchar2 is
-- datos a responder
v_detalles        clob := null;   -- datos de las cuentas

-- datos recibidos
-- v_terminal        number(3)   := substr(p_parametros,1, 3);
v_modo            varchar2(1) := substr(p_parametros,66,1);
v_cod_servicio    varchar2(3) := substr(p_parametros,67,3);   --

-- variables
v_cod_moneda      varchar2(03);
v_cod_mod_cta     number(4);
v_cod_mad_cta     number(4);
v_cod_ofi_cta     number(4);
v_cod_retencion   number(4);     -- codigo de retencion
v_fec_fin_retencion date;        -- fecha final de la retencion
--
v_cod_tra_padre   number(4) := 215;
v_cod_transaccion number(4);
v_nro_cta_debito  varchar2(17) := trim(substr(p_parametros,70,17));
v_cod_mon_debito  varchar2(4);
v_pag_ser_tas_habilitado VARCHAR2(1) := fug_obt_pardinamico('PAG_SER_TAS_HABILITADO');
v_nro_sobre       number(10) := trim(substr(p_parametros, 87,10));
v_imp_efectivo    number(18,2) := nvl(to_number(replace(trim(substr(p_parametros, 97,18)),',','.')),0); -- efectivo
v_imp_che_n_bco   number(18,2) := nvl(to_number(replace(trim(substr(p_parametros, 115,18)),',','.')),0); -- che.ntro.bco
v_imp_che_o_bco   number(18,2) := nvl(to_number(replace(trim(substr(p_parametros, 133,18)),',','.')),0); -- che otros bcos.
v_imp_debito      number(18,2) := nvl(to_number(replace(trim(substr(p_parametros, 151,18)),',','.')),0);   -- debito
v_tot_pago        number(18,2) := nvl(to_number(replace(trim(substr(p_parametros, 169,18)),',','.')),0);   -- total
--
v_cta_for_debito  varchar2(17);  -- cuenta formateada
v_est_cta_debito  varchar2(1);   -- estado de la cuenta
v_cod_mod_debito  number(4);     -- modulo de la cuenta
v_cod_mad_debito  number(4);     -- modalidad de la cuenta
v_cod_ofi_debito  number(4);     -- oficina de la cuenta
v_nvo_est_debito  varchar2(1) := null; -- cambio de estado de cuenta
v_cot_debito      number(18,2) := null;
v_nom_cta_debito  varchar2(100);
v_cotizacion      number(18,4) := null;
r_par ge_cob_ser_parametros%rowtype;
--v_caj_homebanking        cj_cajas.nro_caja%TYPE := fug_obt_pardinamico('NRO_CAJ_HOMEBANKING');
---
v_can_dias       number(3);--   := substr(p_parametros,28,2);   -- cantidad de dias
v_ver_todas      varchar2(3);-- := substr(p_parametros,30,1);   -- ver todas las cuentas s/n
r_cobro          GE_COB_SERVICIOS%ROWTYPE;
v_nro_cuenta     varchar2(17);
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. verifico si operacion no viene del tas (Caja 999) de ser asi devuelvo ope. no permitida
  /*
  Se agrega la validacion para el caso de que se intenten hacer pagos de servicios via TAS. en caso de que esta
  operacion sea habilitada posteriormente se podra cambiar el valor del parametro dinamico PAG_SER_TAS_HABILITADO
  para que la validacion quede sin efecto.
  */
  if v_pag_ser_tas_habilitado = 'N' then
     if fu_caj_homebanking(v_nro_terminal) = 'N' /*v_nro_terminal <> v_caj_homebanking*/ THEN
        v_cod_respuesta := paw_bce.v_cod_ope_no_permitida;
     end if;
  end if;
  --Verifica los permisos  
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '082');
     if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
        v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
     end if;
  end if;        
  -- 3. busco los datos de la cuentas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     begin
       Begin
        Select s.* into r_par
          from ge_cob_ser_parametros s
         where s.cod_servicio = v_cod_servicio;
       exception
            when no_data_found then
              v_cod_respuesta := v_cod_ser_inexistente;
            when others then
              v_cod_respuesta := v_cod_otr_error;
       end;
       if v_cod_respuesta = paw_bce.v_cod_aprobado then
          pag_ser.pr_obt_servicio( v_cod_servicio);
          -- Si se produjo un error
          IF pag_ser.g_cod_error <> 0 THEN
            v_cod_respuesta := v_cod_ser_inexistente;
          END IF;
          v_cod_moneda := pag_ser.g_cod_moneda;
          -- Obtiene la cuenta en donde debe acreditar.
          v_nro_cuenta  := pag_ser.g_nro_cuenta;
          v_cod_mod_cta := pag_ser.g_cod_modulo;
          v_cod_mad_cta := pag_ser.g_cod_modalidad;
          v_cod_ofi_cta := pag_ser.g_cod_oficina;
       End if;
     exception
        when no_data_found then
           v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
     end;
  end if;
  if v_cod_respuesta = paw_bce.v_cod_aprobado then

     -- todo ok, se arma el mensaje de respuesta
     if v_modo in ('V','C') then  -- validacion o confirmacion
        -- esta la cuenta en condiciones, verifico el horario del deposito
        lp_ver_horario;
        -- verifico la validez de los montos
        begin
          -- Ya hace al inicio v_nro_cta_debito
          if v_nro_cta_debito is not null then
            if (instr(v_nro_cta_debito,'-') > 0 or instr(v_nro_cta_debito,' ') > 0) then
               -- se extrae los guiones de la cuenta
                v_nro_cta_debito := to_number(substr(v_nro_cta_debito,7));
            end if;
          end if;
          if v_cod_moneda = v_cod_mon_local then
             if v_imp_efectivo <> trunc(v_imp_efectivo) or
                v_imp_che_n_bco <> trunc(v_imp_che_n_bco) or
                v_imp_che_o_bco <> trunc(v_imp_che_o_bco)  or
                v_imp_debito <> trunc(v_imp_debito) then
               -- monto con decimales y en guaranies no permite
               v_cod_respuesta := paw_bce.v_cod_mto_invalido;
             elsif nvl(v_imp_efectivo,0) + nvl(v_imp_che_n_bco,0) +
                   nvl(v_imp_che_o_bco,0) + nvl(v_imp_debito,0) <> nvl(v_tot_pago,0) then
                   -- total depositado invalido
                   v_cod_respuesta := paw_bce.v_cod_tot_invalido;
             end if;
          end if;
        exception
          when others then
             -- monto invalido
             v_cod_respuesta := paw_bce.v_cod_mto_invalido;
        end;
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
           if v_modo in ('C', 'V') and v_imp_debito > 0 then -- solo se valida
              pr_val_cta_debito( v_nro_cta_debito,
                                 v_cod_tra_padre,
                                 v_imp_debito,
                                 v_cod_mon_debito,
                                 v_cod_mod_debito,
                                 v_cod_mad_debito,
                                 v_cod_ofi_debito,
                                 v_cta_for_debito,
                                 v_nom_cta_debito);
             if v_cod_moneda <> v_cod_mon_debito then
                -- moneda diferentes
                v_cod_respuesta := paw_bce.v_cod_tra_invalida;
             end if;
             If v_modo = 'V' then
               return  lpad(ltrim(lf_for_money(v_cotizacion,16)),16,'0')||
                       lf_for_char(v_cta_for_debito,17)||
                       lf_for_char(v_nom_cta_debito,50)||
                       lf_for_char(rpad(v_cod_mon_debito,3,'.'),3)||
                       lf_for_money(v_imp_debito,16)||
                       lf_for_char(rpad(v_cod_moneda,3,'.'),3)||
                       lf_for_money(v_imp_debito,16);
             End if;
          end if;
          -- sigue sin problemas hasta aqui, ya puedo grabar
          if v_modo = 'C' then
              --- cargar los datos en r_cobro antes de pasarle como parametro
              r_cobro.cod_servicio      := V_cod_servicio;
              r_cobro.tip_cobro         := 'E';
              r_cobro.nro_operacion     := v_nro_operacion;
              r_cobro.fecha             := v_fec_actual;
              r_cobro.hora              := v_hor_actual;
              r_cobro.referencia1       := v_nro_operacion;
              r_cobro.referencia2       := NULL;
              r_cobro.monto             := v_tot_pago;
              r_cobro.cod_moneda        := v_cod_moneda;
              r_cobro.mto_efectivo      := v_imp_efectivo;
              r_cobro.mto_che_otr_banco := v_imp_che_o_bco;
              r_cobro.nro_caja          := to_number(v_nro_terminal);
              r_cobro.mto_debito        := v_imp_debito;
              r_cobro.nro_cta_debito    := v_nro_cta_debito;
              r_cobro.mto_efectivo      := v_imp_efectivo;
              r_cobro.mto_che_nue_banco := v_imp_che_n_bco;
              r_cobro.mto_che_otr_banco := v_imp_che_o_bco;

              if v_cod_respuesta = paw_bce.v_cod_aprobado then -- sino hubo ERROR se arma los datos para grabar
                pag_Ser.pr_ins_cobro( r_cobro, pag_ser.g_cod_transaccion, 'E' );
                if to_number(v_cod_respuesta) = 0 then
                   v_cod_respuesta := paw_bce.v_cod_aprobado;
                end if;

             End if;
            if v_imp_efectivo > 0 then
                -- importe en efectivo
                v_cod_tra_padre   := 215;
                v_cod_transaccion := 613;
                -- v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
                -- DYDMR-773 ERROR EN TAS - SC 5610
                v_hor_actual := FUG_OBT_HOR_DISPONIBLE(v_fec_actual,
                                                       v_hor_actual,
                                                       user,
                                                       v_es_mov_noc);
                -- obtengo el codigo y fin de retencion
                pag_cta.pr_obt_retencion(v_fec_actual,
                                         v_nro_cuenta,
                                         v_cod_mod_cta,
                                         v_cod_mad_cta,
                                         v_cod_transaccion,
                                         v_cod_moneda,
                                         v_cod_retencion,
                                         v_fec_fin_retencion);
                -- genero el movimiento respectivo
                lp_ins_movimiento( v_cod_mod_cta,
                                   v_cod_mad_cta,
                                   v_cod_ofi_cta,
                                   v_nro_cuenta,
                                   v_cod_moneda,
                                   v_cod_tra_padre,
                                   v_cod_transaccion,
                                   v_nro_sobre,
                                   v_imp_efectivo,
                                   'E', -- EFECTIVO
                                   v_es_mov_noc,
                                   v_cod_retencion,
                                   v_fec_fin_retencion);
            end if;
            if v_imp_che_n_bco > 0 then
               -- importe en cheques ntro banco
                v_cod_tra_padre   := 215;
                v_cod_transaccion := 614;
                -- v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
                -- DYDMR-773 ERROR EN TAS - SC 5610
                v_hor_actual := FUG_OBT_HOR_DISPONIBLE(v_fec_actual,
                                                       v_hor_actual,
                                                       user,
                                                       v_es_mov_noc);
                -- obtengo el codigo y fin de retencion
                pag_cta.pr_obt_retencion(v_fec_actual,
                                         v_nro_cuenta,
                                         v_cod_mod_cta,
                                         v_cod_mad_cta,
                                         v_cod_transaccion,
                                         v_cod_moneda,
                                         v_cod_retencion,
                                         v_fec_fin_retencion);
                -- genero el movimiento respectivo
                lp_ins_movimiento( v_cod_mod_cta,
                                   v_cod_mad_cta,
                                   v_cod_ofi_cta,
                                   v_nro_cuenta,
                                   v_cod_moneda,
                                   v_cod_tra_padre,
                                   v_cod_transaccion,
                                   v_nro_sobre,
                                   v_imp_che_n_bco,
                                   'C', -- cheque ntro bco
                                   v_es_mov_noc,
                                   v_cod_retencion,
                                   v_fec_fin_retencion);
            end if;
            if v_imp_che_o_bco > 0 then
               -- importe en cheques otros bancos
                v_cod_tra_padre   := 215;
                v_imp_alt_valor := fug_obt_pardinamico('MTO_CHE_RET_CERO',null,null,v_cod_moneda,null,null );
                IF v_cod_moneda = v_cod_mon_local THEN 
                   /*if v_imp_che_o_bco >= v_imp_alt_valor then  
                     if v_horario = 'D' and v_hor_actual > v_hor_cie_cheques then
                         -- se graba ya como cheques 48 hs de retencion
                        v_cod_transaccion := 632;
                        v_tip_monto       := 'S';
                     else
                        v_cod_transaccion := 607;                
                        v_tip_monto       := 'O';
                     end if;
                  else  */            
                    if v_horario = 'D' and v_hor_actual > v_hor_cie_cheques then
                      -- se graba ya como cheques 48 hs de retencion
                      v_cod_transaccion := 632;
                      v_tip_monto       := 'S';
                    else
                      v_cod_transaccion := 615;
                      v_tip_monto       := 'T';
                    end if;
                  --end if;
                ELSE
                   v_cod_transaccion := 615;
                   v_tip_monto       := 'T';  
                   IF v_horario = 'D' and v_hor_actual > v_hor_cie_cheques THEN
                      -- se graba ya como cheques 48 hs de retencion
                      v_cod_transaccion := 632;
                      v_tip_monto       := 'S';
                   END IF;
                END IF;    
                -- v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
                -- DYDMR-773 ERROR EN TAS - SC 5610
                v_hor_actual := FUG_OBT_HOR_DISPONIBLE(v_fec_actual,
                                                       v_hor_actual,
                                                       user,
                                                       v_es_mov_noc);
                -- obtengo el codigo y fin de retencion
                pag_cta.pr_obt_retencion(v_fec_actual,
                                         v_nro_cuenta,
                                         v_cod_mod_cta,
                                         v_cod_mad_cta,
                                         v_cod_transaccion,
                                         v_cod_moneda,
                                         v_cod_retencion,
                                         v_fec_fin_retencion);
                -- genero el movimiento respectivo
                lp_ins_movimiento( v_cod_mod_cta,
                                   v_cod_mad_cta,
                                   v_cod_ofi_cta,
                                   v_nro_cuenta,
                                   v_cod_moneda,
                                   v_cod_tra_padre,
                                   v_cod_transaccion,
                                   v_nro_sobre,
                                   v_imp_che_o_bco,
                                   v_tip_monto, -- cheque otros bcos
                                   v_es_mov_noc,
                                   v_cod_retencion,
                                   v_fec_fin_retencion);
            end if;
            -- actualizo el control de caja
            update cj_controles
               set tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_imp_che_n_bco,0),
                   sal_actual = nvl(sal_actual,0) + nvl(v_imp_efectivo,0),
                   tot_debitos = nvl(tot_debitos,0) + nvl(v_imp_efectivo,0),
                   can_debitos = nvl(can_debitos,0) + decode(v_imp_efectivo,0,0,1),
                   tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_imp_che_o_bco,0),
                   sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_imp_che_o_bco,0),
                   estado = 1 -- abierto
             where nro_caja = to_number(v_nro_terminal)
               and cod_moneda = v_cod_moneda
               and fecha = v_fec_actual;
            if sql%notfound then
               insert into cj_controles
                 (nro_caja, cod_moneda, fecha, estado,
                  mto_apertura, ini_che_otr_bco, cod_usu_actual,
                  tot_che_nue_bco, sal_actual, tot_debitos,
                  can_debitos, tot_che_otr_bco, sal_che_otr_bco)
               select
                  v_nro_terminal, v_cod_moneda, v_fec_actual, 1,
                  0, 0, v_cod_usuario,
                  v_imp_che_n_bco, v_imp_efectivo, v_imp_efectivo,
                  decode(v_imp_efectivo,0,0,1), v_imp_che_o_bco,
                  v_imp_che_o_bco from dual;
            end if;
            if v_imp_debito > 0 then
                -- seteo las variables para el credito
                pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                                          v_fec_valor,
                                          v_cod_tra_padre, 'N', 'N',
                                          v_nro_secuencia,
                                          null, v_cod_ofi_origen, 9, 91);
                -- esta la cuenta en condiciones, verifico el horario
                lp_ver_horario;
                -- Procesa el credito en la entidad...
                pag_cta.pr_act_operacion(v_nro_cuenta,
                                v_hor_actual,
                                'C',
                                v_cod_moneda,           ---ver
                                v_imp_debito,
                                v_cod_tra_padre,  ---ver
                                602,
                                v_nro_sobre,
                                v_cotizacion,            --- ver
                                v_cod_ofi_origen,
                                9,
                                91,
                                NULL,
                                NULL,
                                'Credito p/ Cobros en Autoservicio',
                                'S',
                                v_nro_secuencia,
                                v_fec_actual,
                                NULL,
                                NULL );
               -- Procesa el debito de la cuenta.
                pag_cta.pr_act_operacion(v_nro_cta_debito,
                                v_hor_actual,
                                'D',
                                v_cod_mon_debito,           ---ver
                                v_imp_debito,
                                v_cod_tra_padre,  ---ver
                                503,
                                v_nro_sobre,
                                v_cotizacion,            --- ver
                                v_cod_ofi_origen,
                                9,
                                91,
                                NULL,
                                NULL,
                                'Debito p/ Cobros en Autoservicio',
                                'S',
                                v_nro_secuencia,
                                v_fec_actual,
                                NULL,
                                NULL);
                ---
            end if;

          end if;
       end if;
     end if;
     return null;
  else
     return null;  -- nada
  end if;
  return null;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin del mensaje a la entidad

-- Consulta de Cliente para Extracto
function fu_pro_operacion_083(p_parametros in varchar2)
  return varchar2 is
-- datos a responder
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. cargo los datos del oficial, si es valido
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
   -- registro del movimiento
   lp_reg_operacion;
     -- todo ok, se arma el mensaje de respuesta
     return lf_for_number(nvl(v_cod_per_empresa,v_cod_persona),7);
  else
     return null;  -- nada
  end if;
end;  -- Fin de consulta de codigo de cliente

-- 085 Extractos en formato texto para el IVR
function fu_pro_operacion_085(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_nro_cta_especifica varchar2(16) := trim(substr(p_parametros,66,16)); -- cuenta especifica a consultar
--
v_detalles        clob := null;   -- datos de las cuentas
-- variables

begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 1.1. Armo el nro de cuenta
  v_nro_cta_especifica := lf_obt_cta_limpia(v_nro_cta_especifica);
  -- 2. ejecuto los datos de impresion de extracto
  v_detalles := fuw_imp_extracto(nvl(v_cod_per_empresa,v_cod_persona),v_nro_cta_especifica);
  if trim(v_detalles) is null then
      -- no hay extractos
      v_cod_respuesta  := paw_bce.v_cod_cta_sin_mov;
  end if;
  -- registro del movimiento
  lp_reg_operacion(v_nro_cta_especifica /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Nro.Cuenta' /*p_etiqueta*/,
                   v_nro_cta_especifica /*p_dato*/
                 );
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return v_detalles;
  else
     return null;  -- nada
  end if;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 085 - Extractos en formato ascii

-- 086 - Consulta de Transferencia al Exterior Cabecera y Detalle
-- OMM 07/01/2011
function fu_pro_operacion_086(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_tip_consulta varchar2(1) := trim(substr(p_parametros,66,1)); -- C= Cabecera, D= Detalle
--
v_fec_desde      date;
v_fec_hasta      date;
v_nro_operacion  varchar2(20) ;
v_can_detalles   number(3) := 0 ;
v_detalles       clob := null;   -- datos de las cuentas
-- variables
Cursor cabecera (p_fec_desde date, p_fec_hasta date, p_cod_persona varchar2) is
  Select 'ENV' Tip_trans, a.nro_ref_externa, a.fec_operacion, a.nro_cta_referencia,
     a.nom_beneficiario, 'ENVIADA AL SWIFT' Estado, a.cod_moneda, a.monto
  from lc_transferencias a
  where a.cod_modalidad = 72 -- Solo la modalidad de Transferencia enviada
    and a.fec_operacion >= p_fec_desde
    and a.fec_operacion <= p_fec_hasta
    and a.cod_per_solicitante = nvl(v_cod_per_empresa,v_cod_persona)
    and a.estado = 'E' -- Solo los de estados Enviado al Swift
    union all
  Select 'REC' Tip_trans, a.nro_ref_externa, a.fec_operacion, a.nro_cta_referencia,
     a.nom_solicitante, 'PAGADA' Estado, a.cod_moneda, a.monto
  from lc_transferencias a
  where a.cod_modalidad = 75 -- Solo la modalidad de Trnasferencia Recibida
    and a.fec_operacion >= p_fec_desde
    and a.fec_operacion <= p_fec_hasta
    and (a.cod_per_beneficiario = nvl(v_cod_per_empresa,v_cod_persona)
        or
        a.nro_doc_beneficiario = (Select p.nro_documento
                                  from ba_personas p
                                  where p.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)))
    and a.estado = 'OK'  -- Solo los de estados Pagados
    order by fec_operacion, nro_ref_externa ;

Cursor detalles (p_referencia varchar2) is
    Select decode(t.cod_modalidad,72,'E','R') Tipo, nvl(t.nom_beneficiario, t.nom_ordenante) Beneficiario, t.nom_solicitante Solicitante,
        t.nro_ref_externa Referencia, t.nro_operacion Operacion, t.fec_operacion Fec_operacion, t.nom_banco Banco,
           nvl((Select gb.descripcion from ge_bancos gb where gb.cod_banco = t.cod_bco_corresponsal),t.cod_bco_corresponsal) Corresponsal,
           t.cod_moneda Moneda, t.monto Monto, t.fec_valor Fec_valor, t.msj_swift Swift
    from lc_transferencias t
    where t.nro_ref_externa = p_referencia ;

begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. Verifico que tipo de dato se solicita.
  if v_tip_consulta = 'C' or v_tip_consulta = 'X' then
     if trim(substr(p_parametros,67,8)) is not null then
        v_fec_desde   := to_date(substr(p_parametros,67,8),'DD/MM/YYYY'); -- Fecha Desde
     end if;
     if trim(substr(p_parametros,75,8)) is not null then
        v_fec_hasta   := to_date(substr(p_parametros,75,8),'DD/MM/YYYY'); -- Fecha Hasta
     end if;

     if v_fec_desde is null  then
        v_fec_desde := v_fec_actual - 30 ;
        v_fec_hasta := v_fec_actual ;
     end if ;

     if v_fec_hasta < v_fec_desde then
         v_cod_respuesta  := paw_bce.v_fec_invalida ;
     end if ;

     if (v_fec_hasta - v_fec_desde) > 60 then
         v_cod_respuesta  := paw_bce.v_fec_exceso ;
     end if ;

       if v_cod_respuesta = v_cod_aprobado then
           for cb in cabecera (v_fec_desde, v_fec_hasta, v_cod_persona) loop
               v_can_detalles := v_can_detalles +1 ;
               v_detalles := v_detalles ||
                             lf_for_char(cb.tip_trans, 3) ||
                             lf_for_char(cb.nro_ref_externa, 20) ||
                             lf_for_date(cb.fec_operacion) ||
                             lf_for_char(cb.nro_cta_referencia, 20) ||
                             lf_for_char(cb.nom_beneficiario, 100)||
                             lf_for_char(cb.estado, 16)||
                             lf_for_char(cb.cod_moneda,3) ||
                             lf_for_money(cb.monto,18) ;
            end loop;
        end if ;
  else
     v_nro_operacion  := trim(substr(p_parametros,67,20));

     if v_nro_operacion is null then
        v_cod_respuesta  := paw_bce.v_ref_invalida ;
     end if ;

    if v_cod_respuesta = v_cod_aprobado then
           for dt in detalles (v_nro_operacion) loop
               v_can_detalles := v_can_detalles +1 ;
               v_detalles := v_detalles ||
               lf_for_char(dt.tipo,1)         ||
                             lf_for_char(dt.beneficiario, 100) ||
                             lf_for_char(dt.solicitante, 100)  ||
                             lf_for_char(dt.referencia, 20)    ||
                             lf_for_number(dt.operacion, 15)   ||
                             lf_for_date(dt.fec_operacion)     ||
                             lf_for_char(dt.banco, 100)        ||
                             lf_for_char(dt.corresponsal, 100) ||
                             lf_for_char(dt.moneda, 3)         ||
                             lf_for_money(dt.monto,20)         ||
                             lf_for_date(dt.fec_valor)         ||
                             lf_for_char(dt.swift, 4000) ;
            end loop;
        end if ;

  end if ;

  if trim(v_detalles) is null and v_tip_consulta <> 'C' and v_cod_respuesta = paw_bce.v_cod_aprobado then
      -- no hay detalles
      v_cod_respuesta  := paw_bce.v_ref_invalida;
  end if;
  -- registro del movimiento
  lp_reg_operacion(null, -- nro_cuenta
                   null, -- cod_moneda
                   null, -- monto
                   null, -- nro_cta_contra
                   null, -- cantidad
                   'Tipo Consulta', -- Etiqueta 1
                   v_tip_consulta,  -- Dato 1
                   'Cantidad/Referencia', -- Etiqueta 2
                   nvl(v_nro_operacion, v_can_detalles), -- Dato 2
                   null, -- Observaciones
                   null, -- Dir_IP
                   (v_fec_desde||' - '|| v_fec_hasta)
                 );
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return lf_for_number(v_can_detalles, 3) || v_detalles;
  else
     return null;  -- nada
  end if;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 086 - Consulta de Transferencia al Exterior

-- Inicio 087 - Validación de la sesión para Pago de Servicios
-- OMM 23/02/2011
function fu_pro_operacion_087(p_parametros in varchar2)
  return varchar2 is
v_nro_sesion        varchar2(32);
v_nro_ip            varchar2(15);
v_cod_persona       varchar2(10);
v_cod_per_vinculada varchar2(10);
v_cuenta            varchar2(15);
-- para límite de operaciones
v_res_limite  varchar2(2);
v_modo        varchar2(1);
-- 
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  v_nro_sesion  := trim(substr(p_parametros,70,32));
  v_nro_ip      := translate(trim(substr(p_parametros,102,15)),chr(13)||chr(10),' ');
  v_cod_persona := trim(substr(p_parametros,33,10));
  v_cod_per_vinculada := trim(substr(p_parametros,50,10));
  v_cuenta      := trim(substr(p_parametros,117,15)); -- cuenta elegida para el débito
  
  if v_cod_respuesta = paw_bce.v_cod_aprobado and v_nro_sesion is not null then
    if lf_val_cta_origen(v_cuenta, nvl(v_cod_per_vinculada, v_cod_persona)) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
    end if;
  end if;
  -- controlamos que la cuenta no sea conjunta
  if v_cod_respuesta = paw_bce.v_cod_aprobado and fu_es_conjunta(v_cuenta) = 'S' then
    v_cod_respuesta := paw_bce.v_cod_cta_invalida;   
  end if;
  -- verificamos cuando fue la última vez que generó la sesión 
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if pag_ser.fu_val_ins_sesion(v_cod_persona, v_cod_per_vinculada) = 'N' then
      v_cod_respuesta := paw_bce.v_err_ses_servicio;
    end if;
  end if;
  -- obtenemos el modo 
  if v_nro_sesion is null then
    v_modo := 'V';
  else
    v_modo := 'C';
  end if;
  -- controlamos el límite
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    v_res_limite := fu_obt_limite('082', 
                    nvl(v_cod_per_vinculada, v_cod_persona), 
                    null, 
                    pag_gen.FU_OBT_MON_LOCAL,
                    503, 
                    485, 
                    1,
                    v_modo ); 
  end if;
 
  -- para límite de operaciones
  if v_cod_respuesta = paw_bce.v_cod_aprobado and v_nro_sesion is not null then
     if v_res_limite IN ('10', '11')  then -- clave transaccional requerida
        v_cod_respuesta := lf_obt_cla_validar(p_parametros,v_cod_persona,v_cod_per_vinculada, 134 /*119*/,'T');
     end if;
     
     if v_cod_respuesta = paw_bce.v_cod_aprobado and v_res_limite IN ('01', '11')  then -- clave transaccional requerida
        v_cod_respuesta := fu_obt_tok_validar(p_parametros,v_cod_persona,v_cod_per_vinculada, 166, v_modo);
     end if;
          
     if v_cod_respuesta = paw_bce.v_cod_aprobado then
        if pag_ser.fu_ins_sesion(v_nro_sesion,v_nro_ip, v_cod_persona, v_cod_per_vinculada, v_cuenta) = 'N' then
          v_cod_respuesta := paw_bce.v_cod_ope_no_permitida;
        end if;
     end if;
  end if;
  
  -- registro del movimiento
  lp_reg_operacion(null, -- Nro cuenta
                   null,
                   null,
                   null,
                   null,
                   'Pago de Servicios',
                   v_nro_sesion,
                   null,
                   null,
                   null,
                   v_nro_ip );

  return v_res_limite;
end;
-- Fin 087 - Consulta de código de cliente Pago de Servicios

-- 095 Calificación de Riesgo Crediticio del Cliente
-- OMM 08/03/2011
function fu_pro_operacion_095(p_parametros in varchar2)
  return varchar2 is
-- datos a responder
v_riesgo       varchar2(50) := null ; -- Categoría de Riesgo
v_fec_riesgo   varchar2(30) := null ;  -- Fecha de Riesgo
v_cat_riesgo   ge_clientes.cat_riesgo%type;
v_fec_clasificacion date;
begin
   -- 1. valido la clave del cliente
   pr_val_clave(p_parametros);
   -- 2. cargo los datos del oficial, si es valido
   IF v_cod_respuesta = paw_bce.v_cod_aprobado THEN
      BEGIN
         -- OMM 23/02/2011 Para Categoria solo GE_CLIENTES
         SELECT pap_cat.fu_obt_cat_crc(nvl(v_cod_per_empresa, v_cod_persona), NULL, 'N')               
           INTO v_cat_riesgo
           FROM ge_clientes g
          WHERE g.cod_persona = nvl(v_cod_per_empresa, v_cod_persona) ;
         -- la ultima fecha calificada, no la ultima fecha modificada 
         select max(trunc(fec_insercion))
           into v_fec_clasificacion
           from ge_cla_operaciones 
          where cod_persona = nvl(v_cod_per_empresa, v_cod_persona);
      EXCEPTION
         WHEN no_data_found THEN
            v_cat_riesgo := NULL;
         WHEN others THEN
            v_cod_respuesta  := paw_bce.v_cod_otr_error;
      END;

      IF v_cat_riesgo IS NULL THEN
         v_cat_riesgo        := 1;
         v_riesgo            := fue_obt_des_refcodes('CAT_RIESGO', v_cat_riesgo);
         v_fec_clasificacion := pag_cal.fu_obt_fec_actual(1);
      ELSE
         v_riesgo     := fue_obt_des_refcodes('CAT_RIESGO', v_cat_riesgo);
         v_fec_riesgo := to_char(v_fec_clasificacion, 'DD/MM/YYYY');
      END IF;
   END IF;
  --
  lp_reg_operacion(null /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Clasif de Riesgos' /*p_etiqueta*/,
                    v_riesgo /*p_dato*/,
                   'Fecha Riesgo' /*p_etiqueta2*/,
                   v_fec_riesgo /*p_dato2*/,
                   null) /*observacion*/;
  --
   IF v_cod_respuesta = paw_bce.v_cod_aprobado THEN
      -- todo ok, se arma el mensaje de respuesta
      RETURN lf_for_char(v_riesgo, 50) || lf_for_char(v_fec_riesgo, 30);
   ELSE
      RETURN NULL; -- nada
   END IF;
END;
--- 095 Fin de la calificacion de riesgo del cliente
-- 099 Devuelve los avisos al cliente por Rango de Fechas
-- OMM 10/11/2011 -- Ajuste para aviso de Nuevo Mensaje
function fu_pro_operacion_099(p_parametros in varchar2)  return varchar2 is
  -- datos recibidos
--v_persona            number(20) := substr(p_parametros, 33, 16);
v_tip_mensaje        varchar2(1) := substr(p_parametros, 66, 1);
v_fecha_desde        date:= to_date(substr(p_parametros, 67, 8),'DD/MM/YYYY');
v_fecha_hasta        date:= to_date(substr(p_parametros, 75, 8),'DD/MM/YYYY');
-- datos a responder
v_can_detalles       number(3) := 0;           -- cantidad de cuentas
v_actualizar         varchar2(1) := 'N' ;
v_nro_secuencia      number(5) ;
--
v_detalles       varchar2(17700) := null; -- datos del Aviso

cursor aviso is
    Select rownum, nro_secuencia, fecha, descripcion,
           decode(estado,'P', 'PENDIENTE','LEIDO') estado, detalle
    from (Select nro_secuencia, fecha, descripcion, estado, detalle
           from cr_per_notas
          where tipo in ('C', 'M')
            and cod_persona = nvl(v_cod_per_empresa, v_cod_persona)
            and fecha between v_fecha_desde and v_fecha_hasta
          order by fecha desc)
    group by rownum, nro_secuencia, fecha, descripcion, estado, detalle
    having rownum < 16
    order by fecha desc, nro_secuencia desc ;
begin

   -- 1. valido la clave del cliente
   pr_val_clave(p_parametros);
   -- 2. Valida el rango de fecha
   if v_fecha_desde > v_fecha_hasta then
      v_cod_respuesta := paw_bce.v_fec_rango_inicial;
   end if;

   if v_cod_respuesta = paw_bce.v_cod_aprobado then
       --
       for av in aviso loop
           v_can_detalles := v_can_detalles + 1;
           v_detalles :=  v_detalles ||
                          lf_for_number(av.nro_secuencia,5)||
                          lf_for_date(av.fecha)||
                          lf_for_char(av.descripcion,80)||
                          lf_for_char(av.estado,10)||
                          lf_for_char(av.detalle,1000);
       end loop;
       --
       if v_can_detalles = 0 then
          -- no tiene cuentas
          v_cod_respuesta  := paw_bce.v_aviso_inexistente;
       end if;
       -- OMM 10/11/2011 Para actualizar el registro
       if v_tip_mensaje = 'D' then
           v_nro_secuencia    := substr(p_parametros, 83, 5);
           Begin
             Select distinct ('S')
                into v_actualizar
                from cr_per_notas
              where tipo in ('C', 'M')
                and cod_persona = nvl(v_cod_per_empresa, v_cod_persona)
                and nro_secuencia = v_nro_secuencia
                and estado = 'P';
            exception
               when others then
                   v_actualizar := 'N';
            end;

            if v_actualizar = 'S' then
                update cr_per_notas
                  set estado = 'R'
                where tipo in ('C', 'M')
                  and cod_persona = nvl(v_cod_per_empresa, v_cod_persona)
                  and nro_secuencia = v_nro_secuencia
                  and estado = 'P';
             end if ;
        end if ;
     -- registro del movimiento
     lp_reg_operacion(null /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Cantidad Msj.' /*p_etiqueta*/,
                   v_can_detalles /*p_dato*/,
                   'Lectura Msj.', /*p_etiqueta2*/
                    v_tip_mensaje                   
                 );
                         
     if v_cod_respuesta = paw_bce.v_cod_aprobado then
          -- todo ok, se arma el mensaje de respuesta
          return lf_for_number(v_can_detalles,3)||
                     v_detalles;
       else
          return null;  -- nada
       end if;
   else
      return null;  -- nada
   end if;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de 099 Devuelve los avisos al cliente por Rango de Fechas

/* 110 -- Devuelve el estado de la clave y clave del cliente al IVR
 solo devolvemos si la clave esta en estado 'P' ya la clave se devuelve
 desencriptada
*/
function fu_pro_operacion_110(p_parametros in varchar2)
  return varchar2 is
  
v_est_cla_cliente bw_ope_claves.est_clave%type;
v_cla_cliente     bw_ope_claves.clave%type;  -- clave encriptada en estado 'P'
v_nro_doc_cliente varchar2(16);
v_nro_doc_empresa varchar2(15);
v_det_respuesta   varchar2(33) := '';
v_nue_clave       number(9);
v_salt            bw_ope_claves.cla_verificador%type;

begin
  v_nro_doc_cliente := trim(substr(p_parametros,66,16));
  v_nro_doc_empresa := trim(substr(p_parametros,82,15));
  v_nue_clave := round(dbms_random.value(100000000, 999999999)); -- clave nueva para devolver al cliente
  -- se obtienen los codigos de personas
  BEGIN
    -- obtenemos el código de la persona física
    select p.cod_persona
      into v_cod_persona
      from ba_personas p 
     where p.nro_documento = v_nro_doc_cliente;
    -- obtenemos el código de persona de la empresa
    if v_nro_doc_empresa is not null then
      select p.cod_persona
        into v_cod_per_empresa
        from ba_personas p 
       where p.nro_documento = v_nro_doc_empresa;
      -- validamos que sea una empresa
      if pag_gen.fu_es_per_fisica(v_cod_per_empresa) = 'S' then
        v_cod_respuesta := paw_bce.v_cod_ope_no_permitida;
      end if;       
    end if;
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
    WHEN too_many_rows THEN
      v_cod_respuesta := paw_bce.v_cod_cta_duplicada;
    WHEN OTHERS THEN
      v_cod_respuesta := paw_bce.v_cod_otr_error;
  END;
  -- validamos el vínculo entre personas
  if v_cod_respuesta = paw_bce.v_cod_aprobado and v_nro_doc_empresa is not null then
    if fu_val_per_vinculada(v_cod_per_empresa, v_cod_persona) = 'N' then
        v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
    end if;
  end if;
  -- no hubo problemas hasta aqui
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    BEGIN
      -- se obtiene los datos de la clave creada, debe estar en estado 'P'
      select a.cla_verificador, a.est_clave
        into v_salt, v_est_cla_cliente
        from bw_ope_claves a
       where a.cod_persona = v_cod_persona
         and (
               (v_nro_doc_empresa is null and a.cod_per_vinculada is null) or 
               (v_nro_doc_empresa is not null and a.cod_per_vinculada = v_cod_per_empresa)
             )
         and a.est_clave = 'P'
         and a.tip_clave = 'A';
      -- encriptamos la clave
      v_cla_cliente := v_salt||'|'||lower(rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_nue_clave))));
      v_cla_cliente := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_cla_cliente)));
      -- seteamos la clave nueva encriptada
      update bw_ope_claves c
         set c.clave = v_cla_cliente
       where c.cod_persona = v_cod_persona
         and (
               (v_nro_doc_empresa is null and c.cod_per_vinculada is null) or
               (v_nro_doc_empresa is not null and c.cod_per_vinculada = v_cod_per_empresa)
             )
         and c.est_clave = 'P'
         and c.tip_clave = 'A';
      -- validamos que solo se haya actualizado un solo registro
      if sql%rowcount <> 1 then
        v_cod_respuesta := paw_bce.v_cod_tra_invalida;
      else
        -- devuelve la clave al IVR
        v_det_respuesta := lf_for_char(v_est_cla_cliente, 1)||lf_for_char(v_nue_clave, 10);
      end if;
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_respuesta := v_cod_pin_inexistente;
      WHEN value_error THEN
        v_cod_respuesta := v_cod_pin_inexistente;
      WHEN too_many_rows THEN
        v_cod_respuesta := v_cod_pin_inexistente;  
    END;
  end if;
  -- para poder registrar el movimiento
  p_clave := 'xxxxxxxxxxxxxxxxx';
  -- registro del movimiento
  lp_reg_operacion(null /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Solicitud Clave IVR' /*p_etiqueta*/,
                   'Acceso' /*p_dato*/
                   );
  
  return v_det_respuesta;
end;
-- fin de fu_pro_operacion_110

-- 111 Setea el estado de la clave del cliente a activo
function fu_pro_operacion_111(p_parametros in varchar2)
  return varchar2 is
v_existe          varchar2(1);
v_nro_doc_cliente varchar2(16);
v_est_cla_cliente varchar2(1);
v_nro_doc_empresa varchar2(15);
begin
  v_nro_doc_cliente := trim(substr(p_parametros,66,16));
  v_est_cla_cliente := trim(substr(p_parametros,82,1));
  v_nro_doc_empresa := trim(substr(p_parametros,83,15));
  -- se obtienen los codigos de personas
  BEGIN
    -- obtenemos el código de la persona física
    select p.cod_persona
      into v_cod_persona
      from ba_personas p 
     where p.nro_documento = v_nro_doc_cliente;
    -- obtenemos el código de persona de la empresa
    if v_nro_doc_empresa is not null then
      select p.cod_persona
        into v_cod_per_empresa
        from ba_personas p 
       where p.nro_documento = v_nro_doc_empresa;
       -- validamos que sea una empresa
       if pag_gen.fu_es_per_fisica(v_cod_per_empresa) = 'S' then
         v_cod_respuesta := paw_bce.v_cod_ope_no_permitida;
       end if;
    end if;
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
    WHEN too_many_rows THEN
      v_cod_respuesta := paw_bce.v_cod_cta_duplicada;
    WHEN OTHERS THEN
      v_cod_respuesta := paw_bce.v_cod_otr_error;
  END;
  -- validamos el vínculo entre personas
  if v_cod_respuesta = paw_bce.v_cod_aprobado and v_nro_doc_empresa is not null then
    if fu_val_per_vinculada(v_cod_per_empresa, v_cod_persona) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
    end if;
  end if;
  -- si no hubo problemas, activamos
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    BEGIN
      if v_est_cla_cliente = 'A' then
        -- busco la clave de la persona
        select 'S'
          into v_existe
          from bw_ope_claves a
         where a.cod_persona = v_cod_persona
           and (
                 (v_nro_doc_empresa is null and a.cod_per_vinculada is null) or
                 (v_nro_doc_empresa is not null and a.cod_per_vinculada = v_cod_per_empresa)
               )
           and a.tip_clave = 'A'
           and a.est_clave = 'P';
        -- seteamos la clave en estado 'A', el usuario podrá ingresar 
        -- al homebanking, pero deberá cambiar su clave
        update bw_ope_claves c
           set c.est_clave = 'A'
         where c.cod_persona = v_cod_persona
           and (
                 (v_nro_doc_empresa is null and c.cod_per_vinculada is null) or
                 (v_nro_doc_empresa is not null and c.cod_per_vinculada = v_cod_per_empresa)
               )
           and c.est_clave = 'P'
           and c.tip_clave = 'A';
        -- validamos que solo se actualice una sola clave
        if sql%rowcount <> 1 then
          v_cod_respuesta := paw_bce.v_cod_tra_invalida;
        end if;    
      else
        v_cod_respuesta := v_cod_otr_error;
      end if;   
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_respuesta := v_cod_pin_inexistente;
      WHEN too_many_rows THEN
        v_cod_respuesta := v_cod_pin_inexistente;
      WHEN others THEN
        v_cod_respuesta := v_cod_pin_inexistente;
    END;
  end if;
  -- para poder registrar el movimiento
  p_clave := 'xxxxxxxxxxxxxxxxx';
  -- registro del movimiento
  lp_reg_operacion(null /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Activar Clave IVR' /*p_etiqueta*/,
                   'Acceso' /*p_dato*/
                   );
  return v_cod_respuesta; -- no se retorna nada
end;
-- fin de 111 Setea el estado de la clave del cliente a activo

-- 112- Consultar linea de Sobregiro
function fu_pro_operacion_112(p_parametros in varchar2)
  return varchar2 is
v_nro_cuenta    ge_cuentas.nro_cuenta%type;
v_cod_moneda    ge_cuentas.cod_moneda%type;
v_lin_sobregiro cc_lin_sobregiros.monto%type;
begin
  -- validamos la clave
  pr_val_clave(p_parametros);
  -- obtenemos la cuenta recibida
  v_nro_cuenta := trim(substr(p_parametros, 66, 15));
  v_nro_cuenta := lf_obt_alfanumerico(v_nro_cuenta, 15);
  -- verifico si existe la cuenta
  begin
    select cod_moneda
      into v_cod_moneda
      from ge_cuentas
     where nro_cuenta = v_nro_cuenta;
  exception
    when others then
      v_cod_respuesta := paw_bce.v_cod_cta_invalida;
  end;
  -- valido que la cuenta pertenezca al cliente
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if lf_val_cta_origen(v_nro_cuenta, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
    end if;
  end if;
  -- no hubo errores hasta aquí
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    v_lin_sobregiro := fuc_obt_mto_lin_sob(v_nro_cuenta);
  end if;
  
  -- registro del movimiento
  lp_reg_operacion(v_nro_cuenta /*p_nro_cuenta*/,
                   v_cod_moneda /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Consulta Sobregiro' /*p_etiqueta*/,
                   v_lin_sobregiro /*p_dato*/
                   );
                   
  return lf_for_number(v_lin_sobregiro, 16);
end;
-- fin de 112 Consulta de sobregiro

-- 113- Consultar saldo o ultimos movimientos de tarjeta
function fu_pro_operacion_113(p_parametros in varchar2)
  return varchar2 is
v_nro_tarjeta  ta_tarjetas.nro_tarjeta%type := replace(trim(substr(p_parametros,66,16)),' ','');
v_can_detalles number(3) := 0;
v_detalles     varchar2(1000);
v_modo         varchar2(1) := substr(p_parametros, 82, 1);
v_saldo        number(18,2);
begin
  -- validamos la clave
  pr_val_clave(p_parametros);
  v_nro_tarjeta := lf_obt_alfanumerico(v_nro_tarjeta, 16); 
  -- valido que la tarjeta pertenezca a la persona
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if lf_val_tar_origen(v_nro_tarjeta, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
    end if;
  end if;
  -- consultamos a bancard
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    case v_modo
      when 'S' then -- obtener saldo
        pag_ban.pr_con_saldos(v_nro_tarjeta);
        if pag_ban.fu_obt_cod_error() != '00' then
          v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
        else
          v_saldo := pag_ban.fu_Dis_com_normal();
        end if;
      when 'M' then -- obtener 3 ultimos movimientos
        v_can_detalles := 3;
        v_detalles := pag_ban.fu_mov_ext_actual(v_nro_tarjeta, 'D', v_can_detalles); 
        if v_detalles is null then
          v_can_detalles := 0;
        end if;  
      else
        v_cod_respuesta := paw_bce.v_cod_tra_invalida;
    end case;
  end if;   
  -- registro del movimiento
  lp_reg_operacion(null /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   v_can_detalles /*p_cantidad*/,
                   v_modo /*p_etiqueta*/,
                   v_nro_tarjeta /*p_dato*/
                   );
                   
  return lf_for_number(v_saldo, 16)||lf_for_number(v_can_detalles, 3)||v_detalles;
end;
-- fin de 113 Consultar saldo o ultimos movimientos de tarjeta

-- 114- Adhesión Débito Automático para Préstamo o Tarjeta
function fu_pro_operacion_114(p_parametros in varchar2)
  return varchar2 is
v_tipo           varchar2(1)  := substr(p_parametros, 66, 1); -- P: Préstamo, T: Tarjeta
v_nro_cuenta     varchar2(16) := trim(substr(p_parametros,67,16)); -- Cuenta préstamo o tarjeta
v_nro_cta_debito varchar2(15) := trim(substr(p_parametros,83,15)); -- Cuenta a debitar
v_deb_automatico varchar2(1);
v_tip_cobro      varchar2(1); -- Tipo de débito para tarjetas M: minimo, T: Total 
-- para validar cuenta débito
v_cod_mon_debito ge_cuentas.cod_moneda%type;
v_cod_mod_debito ge_cuentas.cod_modulo%type;
v_cod_mad_debito ge_cuentas.cod_modalidad%type;
v_cod_ofi_debito ge_cuentas.cod_oficina%type;
v_cta_for_debito ge_cuentas.nro_cuenta%type;
v_nom_cta_debito ge_cuentas.denominacion%type;
-- moneda del préstamo o tarjeta
v_cod_moneda      ba_monedas.cod_moneda%type;
v_nro_cta_tarjeta ta_tarjetas.nro_cuenta%type;
v_cod_tra_padre   ge_transacciones.cod_transaccion%type;                    
begin
  -- validamos la clave
  pr_val_clave(p_parametros);
  v_nro_cuenta := lf_obt_alfanumerico(v_nro_cuenta, 16);
  v_nro_cta_debito := lf_obt_alfanumerico(v_nro_cta_debito, 15);
  -- verificamos el horario
  lp_ver_horario;
  -- verificamos que la cuenta débito pertenezca al cliente
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if lf_val_cta_origen(v_nro_cta_debito, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
    end if;
  end if;
  -- verificamos que solo sean personas físicas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if v_cod_per_empresa is not null then
      v_cod_respuesta := paw_bce.v_cod_tra_prohibida;  
    end if;
  end if;
  -- verificamos que la cuenta débito
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    -- para verificar transacciones prohibidas en la validación de cta. débito
    if v_tipo = 'T' then
      v_cod_tra_padre := 250;
    else
      v_cod_tra_padre := 360;
    end if;
    pr_val_cta_debito(v_nro_cta_debito, 
                      v_cod_tra_padre,
                      0, -- no importa el monto
                      v_cod_mon_debito,
                      v_cod_mod_debito,
                      v_cod_mad_debito,
                      v_cod_ofi_debito,
                      v_cta_for_debito,
                      v_nom_cta_debito);
  end if;
  -- no hubo errores hasta aquí
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    case v_tipo
      -- tarjeta de crédito
      when 'T' then
         -- obtenemos el tipo de debito automatico
         v_tip_cobro := substr(p_parametros,98,1);
         -- obtenemos los datos de la cuenta
         begin
           select nvl(ct.deb_automatico, 'N'), ct.cod_moneda, ta.nro_cuenta
             into v_deb_automatico, v_cod_moneda, v_nro_cta_tarjeta
             from ta_tarjetas ta, ta_cta_tarjetas ct, ge_cta_clientes cc
            where ta.cod_persona = nvl(v_cod_per_empresa, v_cod_persona)
              and ta.nro_cuenta = ct.nro_cuenta
              and ta.nro_cuenta = cc.nro_cuenta
              and cc.relacion = 'P'
              and ta.nro_tarjeta = v_nro_cuenta;                     
           -- verificamos si ya esta asociado a débito automatico
           if v_deb_automatico = 'S' then
             v_cod_respuesta := paw_bce.v_cod_ped_duplicado;  
           end if;
           -- validamos que el tipo sea T o M
           if v_tip_cobro not in ('M', 'T') then
             v_cod_respuesta := paw_bce.v_cod_tra_invalida;
           end if;
         exception
           when others then
             v_cod_respuesta := paw_bce.v_cod_cta_invalida;
         end;
         -- validamos las monedas
         if v_cod_respuesta = paw_bce.v_cod_aprobado then
           if v_cod_moneda <> v_cod_mon_debito then
             v_cod_respuesta := paw_bce.v_cod_tra_invalida;
           end if;
         end if;
         -- no hubo problemas, aderimos al servicio de debito automático
         if v_cod_respuesta = paw_bce.v_cod_aprobado then
           update ta_cta_tarjetas t
              set t.deb_automatico = 'S', 
                  t.nro_cta_debito = v_nro_cta_debito,
                  t.tip_cobro = v_tip_cobro
            where t.nro_cuenta = v_nro_cta_tarjeta;
           -- verificamos si se agregó al débito
           if sql%rowcount <> 1 then
             v_cod_respuesta := paw_bce.v_cod_ope_no_permitida;
           end if;
         end if;
      -- préstamo  
      when 'P' then
        -- obtenemos los datos de la cuenta
        begin          
          select pr.cob_automatico, pr.cod_moneda
            into v_deb_automatico, v_cod_moneda
            from pr_cta_prestamos pr, ge_cta_clientes gc
           where pr.nro_cuenta = gc.nro_cuenta
             and pr.nro_cuenta = v_nro_cuenta
             and gc.relacion = 'P'
             and gc.cod_persona = nvl(v_cod_per_empresa, v_cod_persona);
        exception
          when others then
            v_cod_respuesta := paw_bce.v_cod_cta_invalida;
        end;
        -- validamos si ya tiene asociado débito automático
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
          if v_deb_automatico = 'S' then 
            v_cod_respuesta := paw_bce.v_cod_ped_duplicado;
          end if;
        end if;
        -- validamos las monedas
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
          if v_cod_mon_debito <> v_cod_moneda then
            v_cod_respuesta := paw_bce.v_cod_tra_invalida;
          end if;
        end if;
        -- no hubo problemas, aderimos al servicio de débito automático
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
          update pr_cta_prestamos p
             set p.cob_automatico = 'S', 
                 p.nro_cta_debito = v_nro_cta_debito
           where p.nro_cuenta = v_nro_cuenta;
          -- verificamos si se agregó al débito
          if sql%rowcount <> 1 then
            v_cod_respuesta := paw_bce.v_cod_ope_no_permitida;
          end if;
         end if;
      else
        v_cod_respuesta := paw_bce.v_cod_tra_invalida;
    end case;
  end if;
  
  -- registro del movimiento
  lp_reg_operacion(v_nro_cta_debito /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   v_tipo /*p_etiqueta*/,
                   v_nro_cuenta /*p_dato*/
                   );
                   
  return null;
end;
-- fin de 114 Adhesión Débito Automático para Préstamo o Tarjeta

-- 115- Consulta de clientes con clave de acceso por CI
function fu_pro_operacion_115(p_parametros in varchar2)
  return varchar2 is
v_nro_documento   ba_personas.nro_documento%type := trim(substr(p_parametros, 66, 20));
v_nro_doc_empresa ba_personas.nro_documento%type := trim(substr(p_parametros, 86, 15));
v_clave         varchar2(1);
begin
  v_nro_documento := lf_obt_alfanumerico(v_nro_documento, 20);  
  -- verifico si existe el cliente
  begin
    -- obtengo el código de persona
    select p.cod_persona
      into v_cod_persona
      from ba_personas p
     where p.nro_documento = v_nro_documento
       and rownum=1;
    -- validamos el ruc de la empresa
    if v_nro_doc_empresa is not null then
      select p.cod_persona
        into v_cod_per_empresa
        from ba_personas p 
       where p.nro_documento = v_nro_doc_empresa;
    end if;
    -- obtengo el perfil
    select c.cod_perfil
      into v_cod_perfil
      from ge_clientes c
     where c.cod_persona = v_cod_persona
       and rownum=1;
  exception
    when no_data_found then
      v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
    when others then
      v_cod_respuesta := paw_bce.v_cod_otr_error;
  end;
  -- verificamos la persona física
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if pag_gen.fu_es_per_fisica(v_cod_persona) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_tra_invalida;
    end if;
  end if;
  -- verificamos la persona jurídica
  if v_cod_respuesta = paw_bce.v_cod_aprobado and v_nro_doc_empresa is not null then 
    if pag_gen.fu_es_per_fisica(v_cod_per_empresa) = 'S' then
      v_cod_respuesta := paw_bce.v_cod_tra_invalida;
    end if;
  end if;
  -- validamos el vínculo entre personas
  if v_cod_respuesta = paw_bce.v_cod_aprobado and v_nro_doc_empresa is not null then
    if fu_val_per_vinculada(v_cod_per_empresa, v_cod_persona) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
    end if;
  end if;
  -- verifico si posee clave de acceso
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if v_cod_perfil is not null then
      begin
        select 'S'
          into v_clave
          from bw_ope_claves b
         where b.cod_persona = v_cod_persona
           and 
             (
               (v_nro_doc_empresa is null and b.cod_per_vinculada is null) or
               (v_nro_doc_empresa is not null and b.cod_per_vinculada = v_cod_per_empresa)
             )
           and b.tip_clave = 'A';
      exception
        when no_data_found then
          v_clave := 'N';
      end;
    else
      v_clave := 'N';
    end if;
  end if;
  -- para poder registrar el movimiento
  p_clave := 'xxxxxxxxxxxxxxxxx';
  -- registro del movimiento
  lp_reg_operacion(null /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'CI' /*p_etiqueta*/,
                   v_nro_documento /*p_dato*/,
                   'Tiene Clave Acceso' /*p_etiqueta2*/,
                   nvl(v_clave, 'N') /*p_dato2*/
                   );
        
  return v_clave;
end;
-- fin de 115 Consulta de clientes con clave de acceso por CI

-- 116- Consulta de próximos vencimientos de préstamos
function fu_pro_operacion_116(p_parametros in varchar2)
  return varchar2 is
v_nro_prestamo varchar2(15) := trim(substr(p_parametros, 66, 15));
v_can_detalles number(4);
v_can_cuotas   number := 0;
v_detalles     varchar2(7800); -- máx. de 300 cuotas
-- cursor de cuotas de préstamos
cursor c_cuotas(p_nro_cuenta in ge_cta_clientes.nro_cuenta%type,
                p_can_cuotas in number) IS
  select nvl(c.sal_capital,0) + nvl(c.sal_interes,0) + nvl(c.sal_int_documentado,0) mto_cuota, c.fec_vencimiento, c.nro_cuota
    from pr_cuotas c
   where c.nro_cuenta = p_nro_cuenta   
     and c.estado = 'C'
     --and c.mto_capital > 0
     and nvl(c.sal_capital,0) + nvl(c.sal_interes,0) + nvl(c.sal_int_documentado,0) > 0
     and (p_can_cuotas = 0 or (p_can_cuotas > 0 and rownum <= p_can_cuotas))
   order by c.fec_vencimiento asc;  
begin
  -- validamos la clave
  pr_val_clave(p_parametros);
  v_nro_prestamo := lf_obt_alfanumerico(v_nro_prestamo, 15);
  -- validamos que el préstamo pertenezca al cliente
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if lf_val_cta_origen(v_nro_prestamo, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
    end if;
  end if;
  -- obtenemos la cantidad de cuotas solicitadas
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    begin
      v_can_detalles := to_number(nvl(trim(substr(p_parametros, 81, 4)), 0));
    exception
      when others then
        v_cod_respuesta := paw_bce.v_cod_tra_invalida;
    end;
  end if;
  -- no hubo problemas hasta aquí
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    -- verificamos el máximo detalle
    if v_can_detalles > 300 then
      v_can_detalles := 0;
    end if;
    -- obtenemos el detalle de las cuotas
    for ct in c_cuotas(v_nro_prestamo, v_can_detalles) loop
      v_can_cuotas := v_can_cuotas + 1;
      v_detalles := v_detalles||lf_for_money(ct.mto_cuota, 16)
                              ||lf_for_char(ct.fec_vencimiento, 10)
                              ||lf_for_number(ct.nro_cuota, 3);      
    end loop;
  end if;
  -- registro del movimiento
  lp_reg_operacion(v_nro_prestamo /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   v_can_cuotas /*p_cantidad*/,
                   null /*p_etiqueta*/,
                   null /*p_dato*/
                   );
                   
  return lf_for_number(v_can_cuotas, 3)||v_detalles;
end;
-- fin de 116 Consulta de próximos vencimientos de préstamos

-- 117- Consulta de saldo de cuenta principal
function fu_pro_operacion_117(p_parametros in varchar2)
  return varchar2 is
v_nro_cuenta ge_cuentas.nro_cuenta%type := null;
v_saldo      ge_cuentas.sal_promedio%type;
v_cod_moneda ge_cuentas.cod_moneda%type;
begin
  -- validamos la clave
  pr_val_clave(p_parametros);
  -- verificamos el horario
  lp_ver_horario;
  -- obtenemos la cuenta principal
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    begin
      -- busco la cuenta con mas movimientos en los últimos 20 días
      select nro_cuenta
        into v_nro_cuenta
        from 
        (
          select gm.NRO_CUENTA, count(0)
            from 
            (
               -- histórico cajas de ahorro
               select ahis.nro_cuenta 
                 from ah_movimientos_his ahis 
                where ahis.fecha >= sysdate - 20
                     --and ahis.cod_persona = nvl(v_cod_per_empresa, v_cod_persona)
                  and ahis.nro_cuenta in
                  (
                     select a.nro_cuenta
                       from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
                      where a.nro_cuenta = b.nro_cuenta
                        and b.relacion = 'P'
                        and b.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
                        and a.cod_modulo = c.cod_modulo
                        and a.cod_modalidad = c.cod_modalidad
                        and a.cod_modulo = 3
                        and a.cod_modalidad = 31
                        and a.estado = c.estado
                        and b.cod_modulo != 7
                        and b.cod_modalidad <> 36
                        and c.activo = 'S'  -- solo cuentas activas
                        and a.estado <> 'X' -- pendiente de verificación
                  ) 
                union all 
               -- históricos cuentas corrientes
               select chis.nro_cuenta 
                 from cc_movimientos_his chis
                where chis.fecha >= sysdate - 20
                     --and chis.cod_persona = nvl(v_cod_per_empresa, v_cod_persona)
                  and chis.nro_cuenta in 
                  (
                     select a.nro_cuenta
                       from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
                      where a.nro_cuenta = b.nro_cuenta
                        and b.relacion = 'P'
                        and b.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
                        and a.cod_modulo = c.cod_modulo
                        and a.cod_modalidad = c.cod_modalidad
                        and a.cod_modulo = 4
                        and a.cod_modalidad = 41
                        and a.estado = c.estado
                        and b.cod_modulo != 7
                        and b.cod_modalidad <> 36
                        and c.activo = 'S'  -- solo cuentas activas
                        and a.estado <> 'X' -- pendiente de verificación
                  ) 
            ) gm
           group by gm.NRO_CUENTA
           order by count(0) desc
        ) 
       where rownum=1;
    exception
      when no_data_found then
        null;     
      when others then -- error al obtener los movimientos historicos
        v_cod_respuesta := paw_bce.v_cod_otr_error;
    end;
  end if;
  -- si no encontramos cuentas con mas movimientos en los ultimos 20 dias, 
  -- buscamos la cuenta mas antigua
  if v_cod_respuesta = paw_bce.v_cod_aprobado and v_nro_cuenta is null then
    begin
      select nro_cuenta
        into v_nro_cuenta
        from 
        (
           select a.nro_cuenta, a.cod_modulo, a.cod_modalidad, a.cod_moneda
             from ge_est_cuentas c,ge_cuentas a, ge_cta_clientes b
            where a.nro_cuenta = b.nro_cuenta
              and b.relacion = 'P'
              and b.cod_persona = nvl(v_cod_per_empresa,v_cod_persona)
              and a.cod_modulo = c.cod_modulo
              and a.cod_modalidad = c.cod_modalidad
              and a.cod_modulo in (3, 4)
              and a.cod_modalidad in (31, 41)
              and a.estado = c.estado
              and b.cod_modulo != 7
              and b.cod_modalidad <> 36
              and c.activo = 'S'  -- solo cuentas activas
              and a.estado <> 'X' 
            order by a.fec_apertura asc) 
       where rownum=1;
    exception
      when no_data_found then
        v_cod_respuesta := paw_bce.v_cod_cta_inexistente;
      when others then
        v_cod_respuesta := paw_bce.v_cod_cta_duplicada;
    end;
  end if;
  -- sino hubo error obtenemos el saldo actual de la cuenta
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     pag_cta.pr_obt_cuenta(v_nro_cuenta);
     if pag_cta.g_cod_error = 0 then
       v_saldo := pag_cta.FU_SAL_DISPONIBLE;
       v_cod_moneda := pag_cta.G_CTAS.cod_moneda;
     else
       v_cod_respuesta := paw_bce.v_cod_cta_invalida;
     end if;
  end if;  
  -- registro del movimiento
  lp_reg_operacion(v_nro_cuenta, -- p_nro_cuenta
                   null, -- p_cod_moneda
                   null, -- p_monto
                   null, -- p_nro_cta_contra
                   null, -- p_cantidad
                   'Saldo', -- p_etiqueta
                   v_saldo -- p_dato
                   );
                   
  return lf_for_char(v_nro_cuenta, 16)||lf_for_char(v_saldo, 18)||lf_for_char(v_cod_moneda, 3);
end;
-- fin de 117 Consulta de saldo de cuenta principal

-- 213- Impresion de extractos de tarjetas
function fu_pro_operacion_213(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_nro_tarjeta     varchar2(16) := replace(trim(substr(p_parametros,66,16)),' ','');
v_mes             number(2)   := nvl(to_number(trim(substr(p_parametros,82,2))),0);
v_anho            number(4) := nvl(to_number(trim(substr(p_parametros,84,4))),0);
---
v_detalles        clob := null;   -- datos de las cuentas
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  
  -- valido que la tarjeta pertenezca a la persona
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    if lf_val_tar_origen(v_nro_tarjeta, nvl(v_cod_per_empresa, v_cod_persona)) = 'N' then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
    end if;
  end if;
  
  -- 2. ejecuto la funcion para generar el comprobante
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     v_detalles := fuw_imp_ext_tarjeta(v_nro_tarjeta, v_mes, v_anho);
  end if;
  -- registro del movimiento
  lp_reg_operacion(v_nro_tarjeta /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Anho' /*p_etiqueta*/,
                   v_anho /*p_dato*/,
                   'Mes',
                   v_mes
                 );
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return v_detalles;
  else
     return null;  -- nada
  end if;
end;
-- fin de 213-impresion de extractos de tarjetas de credito

-- 214 -validación o confirmación de transferencia con contrato de cambio
function fu_pro_operacion_214(p_parametros      in varchar2,
                              p_nro_cta_debito  in varchar2 default null,
                              p_monto           in number   default null,
                              p_nro_cta_credito in varchar2 default null,
                              p_modo            in varchar2 default null,
                              p_cotizacion      in number   default null,
                              p_mto_credito     in number   default null,
                              p_cot_credito     in number   default null,
                              p_nro_doc_credito in varchar2 default null,
                              p_concepto        in varchar2 default null,
                              p_nro_referencia  in number   default null
  )
  return varchar2 is
-- datos recibidos
v_nro_cta_debito  varchar2(16);
v_monto           number(18,2);   -- monto a transferir
v_nro_cta_credito varchar2(17);   -- cuenta de credito
v_modo            varchar2(1);    -- modo V-validacion o C-confirmacion
-- variables
v_cta_for_debito  varchar2(17);  -- cuenta formateada
v_cod_mon_debito  varchar2(3);   -- moneda de la cuenta
v_cod_mon_adebito varchar2(3);   -- moneda debito del contrato
v_est_cta_debito  varchar2(1);   -- estado de la cuenta
v_cod_mod_debito  number(4);     -- modulo de la cuenta
v_cod_mad_debito  number(4);     -- modalidad de la cuenta
v_cod_ofi_debito  number(4);     -- oficina de la cuenta
v_nvo_est_debito  varchar2(1) := null; -- cambio de estado de cuenta
v_cot_debito      number(18,2) := null;
v_nom_cta_debito  varchar2(100);

v_nro_contrato     number(10);
v_nro_operacion    number(10);
v_mto_contrato     number(18,2);
v_cod_mon_credito  varchar2(3);   -- moneda de la cuenta
v_cod_mon_acredito varchar2(3);   -- moneda credito del contrato
v_cta_for_credito  varchar2(17);  -- cuenta formateada
v_est_cta_credito  varchar2(1);   -- estado de la cuenta
v_cod_mod_credito  number(4);     -- modulo de la cuenta
v_cod_mad_credito  number(4);     -- modalidad de la cuenta
v_cod_ofi_credito  number(4);     -- oficina de la cuenta
v_nvo_est_credito  varchar2(1) := null; -- cambio de estado de cuenta
v_sal_dis_credito  number(18,2);
v_mto_credito      number(18,2) ;
v_cot_credito      number(18,4) := null;
v_nom_cta_credito  varchar2(100);
v_mto_equ_local    number(18) := null;
v_mto_debito       number(18,2) ;

v_cod_tra_padre   number(4)  := 388;     -- cod. transaccion padre
v_procesa         varchar2(1) := 'N';    -- indica si se puede o no procesar
v_cotizacion      number(18,2) := null;
v_nro_documento   number(15);
v_nro_doc_credito varchar2(20) := null;  -- nro de documento del acreditado
--v_mto_limite      number(18,2);   -- monto límite para transferencias
--v_tot_realizado   number(18,2);   --
v_concepto        varchar2(35);
v_tip_operacion   varchar2(1) ; -- Tipo operacion
v_dir_ip          varchar2(20);
v_des_operacion   varchar2(10);
v_res_limite      varchar2(2);  -- Para límite de operaciones
v_mod_limite      varchar2(1);
v_res_notificacion number(3); --Respuesta de limite
begin
  -- 0. inicializo la secuencia
  v_nro_secuencia := 0;
  if nvl(p_modo,'x') = 'A' then
     -- viene de confirmación de una autorización
     v_nro_cta_debito  := p_nro_cta_debito;
     v_monto           := p_monto;
     v_nro_cta_credito := p_nro_cta_credito;
     v_modo            := p_modo;
     v_cotizacion      := p_cotizacion;
     v_mto_credito     := p_mto_credito;
     v_cot_debito      := p_cotizacion;
     v_cot_credito     := p_cot_credito;
     v_nro_doc_credito := p_nro_doc_credito;
     v_concepto        := p_concepto;
     v_nro_contrato    := p_nro_referencia ;
  else
     v_nro_cta_debito  := lf_obt_cta_limpia(trim(substr(p_parametros,77,17)));
     v_nro_cta_credito := lf_obt_cta_limpia(trim(substr(p_parametros,94,17)));   -- cuenta de credito
     v_modo            := substr(p_parametros,76,1);    -- modo V-validacion o C-confirmacion
     v_nro_contrato    := trim(substr(p_parametros,66,10));
     v_dir_ip          := trim(substr(p_parametros,121,20));
     -- 1. valido la clave del cliente
     pr_val_clave(p_parametros);
     if v_modo = 'C' and v_can_aut_requeridas = 0 then
        -- se confirma directamente la operación, porque no requiere autorización
        v_modo := 'A'; -- CONFIRMACIÓN
     end if;
  end if;

  -- OMM 23/05/2011 Se comenta para pruebas
  --jclg/tys no debe validar los permisos si es aprobacion de la 039
  if v_cod_respuesta = paw_bce.v_cod_aprobado and v_nro_doc_credito is not null and nvl(p_modo,'x') <> 'A' then
     -- verifica si tiene permiso para transferencia con contrato de cambio
     v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '214');
     if instr(nvl(v_permiso,'x'),'I') = 0 and instr(v_tip_mensaje,'I') > 0 then
        v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
     end if;
  end if;
  if to_char(sysdate,'HH24:MI') not between
     to_char(to_date(fug_obt_pardinamico('HOR_PRE_ESP_INICIO', 7, 71),'HH24:MI'),'HH24:MI')  and
     to_char(to_date(fug_obt_pardinamico('HOR_PRE_ESP_FIN', 7, 71),'HH24:MI'),'HH24:MI') then
        v_cod_respuesta := paw_bce.v_hor_ope_invalida;
  end if ;

  if v_cod_respuesta = paw_bce.v_cod_aprobado then

    -- OMM Se verifica el contrato de cambio
    begin
       Select decode(l.cod_tip_operacion, 16, 'C', 'V'), l.cotizacion,
              l.monto, decode(l.cod_tip_operacion, 30, v_cod_mon_local, l.cod_moneda),
              decode(l.cod_tip_operacion, 30, l.cod_moneda, v_cod_mon_local), l.mto_equ_local,
              decode(l.cod_tip_operacion, 30, l.mto_equ_local, l.monto),
              decode(l.cod_tip_operacion, 30, l.monto, l.mto_equ_local),
              l.nro_operacion, decode(l.cod_tip_operacion, 16, 'COMPRA', 'VENTA')
         into v_tip_operacion, v_cotizacion, v_monto, v_cod_mon_adebito,
              v_cod_mon_acredito, v_mto_equ_local, v_mto_debito,
              v_mto_credito, v_nro_operacion, v_des_operacion
         from lc_ope_pendientes l
        where l.nro_diario = v_nro_contrato
          and l.liquidado = 'N'
          and l.ope_homebanking = 'S'
          and l.nro_documento = FUE_OBT_NRO_DOC_PERSONA(nvl(v_cod_per_empresa,v_cod_persona))
          and l.fec_operacion = trunc(sysdate);
    exception
       when others then
          v_cod_respuesta := paw_bce.v_con_cam_invalido;
    end;

    if v_modo <> 'V' then
       -- verifico cuenta de débito
       if v_nro_cta_debito = v_nro_cta_credito then
          v_cod_respuesta := paw_bce.v_cod_tra_invalida;
       else
          pr_val_cta_debito( v_nro_cta_debito,
                             v_cod_tra_padre,
                             v_mto_debito,
                             v_cod_mon_debito,
                             v_cod_mod_debito,
                             v_cod_mad_debito,
                             v_cod_ofi_debito,
                             v_cta_for_debito,
                             v_nom_cta_debito);
          if v_modo = 'C' and v_can_aut_requeridas = 0 then
             -- se confirma directamente la operación, porque no requiere autorización
             v_modo := 'A'; -- CONFIRMACIÓN
          end if;
       end if;
          
       -- se valida que la cuenta débito pertenezca al cliente
       if v_cod_respuesta = paw_bce.v_cod_aprobado then             
          if lf_val_cta_origen(v_nro_cta_debito,nvl(v_cod_per_empresa,v_cod_persona)) = 'N' then
             -- no es una cuenta del cliente
             v_cod_respuesta := paw_bce.v_cod_cta_invalida;
          end if;
       end if;
          
       -- se valida que la moneda de la cuenta débito sea la misma que lo especificado en el contrato
       if v_cod_respuesta = paw_bce.v_cod_aprobado and v_cod_mon_adebito <> v_cod_mon_debito then
          v_cod_respuesta := paw_bce.v_cod_tra_invalida;
       end if;

       if v_cod_respuesta = paw_bce.v_cod_aprobado then
          -- cuenta de crédito
          begin
             select a.cod_moneda, a.estado, cod_modalidad,
                    cod_modulo, cod_oficina,
                    fug_cta_formateada(cod_modulo, cod_modalidad, cod_oficina,nro_cuenta, cod_moneda) cta_formateada,
                    denominacion
               into v_cod_mon_credito,
                    v_est_cta_credito, v_cod_mad_credito,
                    v_cod_mod_credito, v_cod_ofi_credito,
                    v_cta_for_credito, v_nom_cta_credito
               from ge_cuentas a
              where a.nro_cuenta = v_nro_cta_credito ; -- contiene el nro de cuenta
          exception
             when others then
                v_cod_respuesta := paw_bce.v_cod_cta_invalida;
          end;
               
          -- se valida que la cuenta crédito pertenezca al cliente
          if v_cod_respuesta = paw_bce.v_cod_aprobado then             
             if lf_val_cta_origen(v_nro_cta_credito,nvl(v_cod_per_empresa,v_cod_persona)) = 'N' then
                -- no es una cuenta del cliente
                v_cod_respuesta := paw_bce.v_cod_cta_invalida;
             end if;
          end if;
          
          -- se valida que la moneda de la cuenta crédito sea la misma que lo especificado en el contrato
          if v_cod_respuesta = paw_bce.v_cod_aprobado and v_cod_mon_acredito <> v_cod_mon_credito then
             v_cod_respuesta := paw_bce.v_cod_tra_invalida;
          end if;

          if v_cod_mad_credito not in (31,41) then
             v_cod_respuesta := paw_bce.v_cod_cta_invalida;
          elsif v_est_cta_credito not in ('A','I','N','S') then
             v_cod_respuesta := paw_bce.v_cod_cta_invalida;
          elsif pag_cta.fu_ver_tra_prohibida(v_nro_cta_credito,v_cod_tra_padre, 9, 91) = 'S' then
             v_cod_respuesta := paw_bce.v_cod_tra_prohibida;
          else
             pag_cta.pr_ver_operacion(v_nro_cta_credito,v_cod_tra_padre,9,91,'C',v_cod_mon_credito, v_mto_credito,
                                         v_cod_ofi_origen, v_cod_mod_credito, v_cod_mad_credito, v_nvo_est_credito,
                                         v_sal_dis_credito, v_procesa,602);
             if v_procesa = 'N' then
                -- no se puede debitar
                v_cod_respuesta := paw_bce.v_cod_cta_invalida;
             elsif v_nro_doc_credito is not null and lf_cta_valida(v_nro_cta_credito, v_nro_doc_credito)='N' then
                -- no se puede acreditar a la cuenta de este nro de documento
                if v_cod_respuesta = paw_bce.v_cod_aprobado then
                   v_cod_respuesta := paw_bce.v_cod_cta_invalida;
                end if;
             end if;
          end if;
       end if ;
    end if ; -- end if v_modo <> 'V'
  end if;
  -- verificamos el modo para envio SMS, se envian dos verificaciones, solo cuando se ingresa el IP
  -- debe enviar el mensaje
  v_mod_limite := v_modo;
  if v_dir_ip is null and v_modo = 'V' then
    v_mod_limite := 'C';
  end if;  
  -- CR: modificado para control de límite de operaciones
  -- si viene de autorizar, no hace falta controlar
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     if v_modo IN ('C', 'V', 'A') and nvl(p_modo,'x') <> 'A' then
        v_res_limite := fu_obt_limite('214', 
                                      nvl(v_cod_per_empresa,v_cod_persona), 
                                      v_nro_cta_debito, 
                                      v_cod_mon_adebito, 
                                      503, 
                                      v_cod_tra_padre,
                                      v_mto_debito,
                                      v_mod_limite);
     end if;
  end if;
  
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     if nvl(p_modo, 'x') <> 'A' and v_modo in ('C','A') then 
        if v_res_limite IN ('10', '11') then -- clave transaccional requerida
           v_cod_respuesta := lf_obt_cla_validar(p_parametros,v_cod_persona,v_cod_per_empresa,143,'T');
        end if;
                
        if v_cod_respuesta = paw_bce.v_cod_aprobado then
           if v_res_limite IN ('01', '11') then -- token requerido
              v_cod_respuesta := fu_obt_tok_validar(p_parametros,v_cod_persona,v_cod_per_empresa,175, v_modo);
           end if;
        end if;  
     end if;
  end if;
  --

  if v_cod_respuesta = paw_bce.v_cod_aprobado then
     -- no hay problemas hasta aquí
     if v_modo = 'V' then -- validación
        -- el cgi que arma el detalle de cuentes espera 'GS.' para 
        -- monedas locales, que recibe del detalle de fu_pro_operacion_011
        if v_cod_mon_adebito = v_cod_mon_local then
           v_cod_mon_debito := 'GS.';
        else
           v_cod_mon_debito := v_cod_mon_adebito;
        end if;
            
        if v_cod_mon_acredito = v_cod_mon_local then
           v_cod_mon_credito := 'GS.';
        else
           v_cod_mon_credito := v_cod_mon_acredito;
        end if;
        --
       
        return lf_for_char(v_nro_contrato, 10)||
               lf_for_char(v_tip_operacion, 1)||
               lf_for_money(v_cotizacion, 16)||
               lf_for_money(v_monto, 16)||
               lf_for_char(v_cta_for_debito, 17)||
               lf_for_char(v_nom_cta_debito, 50)||
               lf_for_char(v_cod_mon_debito, 3)||
               lf_for_char(v_cta_for_credito,17)||
               lf_for_char(v_nom_cta_credito,50)||
               lf_for_char(v_cod_mon_credito,3)||
               lf_for_money(v_mto_equ_local, 16)||
               -- para límite de operaciones
               lf_for_char(v_res_limite, 2);
     elsif v_modo = 'C' then -- grabación en pendiente
        --- inserto el movimiento pendiente de autorización
        select s_nro_documento.nextval into v_nro_documento from dual;
        insert into bw_mov_pendientes
           (nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda,
            descripcion, monto, cotizacion, mto_equ_local, nro_cta_contra,
            estado,can_aut_requeridas, can_aut_faltantes, cod_per_ingreso, mto_contra, cot_contra,
            etiqueta, dato, etiqueta2, dato2, referencia)
        values
           (v_nro_documento,nvl(v_cod_per_empresa,v_cod_persona),sysdate,'214',v_nro_cta_debito,v_cod_mon_debito,
            'Transferencia de Operaciones de Cambios',v_mto_debito, v_cotizacion, v_mto_equ_local, v_nro_cta_credito,
            'P', v_can_aut_requeridas, v_can_aut_requeridas, v_cod_persona, v_mto_credito, v_cotizacion,
            'Nro.Identificacion',v_nro_doc_credito, 'Concepto',v_concepto, v_nro_contrato
           );
          
          -- registro del movimiento
        lp_reg_operacion(v_nro_cta_debito /*p_nro_cuenta*/,
                         v_cod_mon_debito /*p_cod_moneda */,
                         v_mto_debito /*p_monto*/,
                         v_nro_cta_credito /*p_nro_cta_contra*/,
                         null,
                         'Tipo_Ope_Cambios',
                         v_tip_operacion,
                         'Cotizacion',
                         v_cotizacion);
        return lf_for_number(v_can_aut_requeridas,3)||lf_for_number(v_nro_documento,15);
     elsif v_modo = 'A' then -- confirmación de operación
        -- seteo las variables
        v_nro_secuencia := 0;
        pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                                 v_fec_valor,
                                 v_cod_tra_padre, 'N', 'N',
                                 v_nro_secuencia,
                                 null, v_cod_ofi_origen, 9, 91);
        -- esta la cuenta en condiciones, verifico el horario
        lp_ver_horario;
        -- actualizo la cuenta de débito
        pag_cta.PR_ACT_OPERACION(v_nro_cta_debito, v_hor_actual,'D',
                                 v_cod_mon_debito, v_mto_debito,
                                 v_cod_tra_padre, 503, v_nro_operacion,
                                 v_cotizacion, v_cod_ofi_origen, 9, 91,
                                 null, null, nvl(v_concepto,v_des_operacion||' Ope. Cambio '||v_nro_cta_credito),
                                 'N', v_nro_secuencia, v_fec_valor,
                                 null, null, v_mto_equ_local);
        if nvl(pag_cta.g_cod_error,0)= 0 then
           pag_cta.PR_ACT_OPERACION(v_nro_cta_credito, v_hor_actual,'C',
                                    v_cod_mon_credito, v_mto_credito,
                                    v_cod_tra_padre, 602, v_nro_operacion,
                                    v_cotizacion, v_cod_ofi_origen, 9, 91,
                                    null, null, nvl(v_concepto,v_des_operacion||' Ope. Cambio '||v_nro_cta_debito),
                                    'N', v_nro_secuencia, v_fec_valor,
                                    null, null, v_mto_equ_local);
           if nvl(pag_cta.g_cod_error,0)<> 0 then
              -- hubo error en el crédito
              if v_cod_respuesta = paw_bce.v_cod_aprobado then
                 v_cod_respuesta := paw_bce.v_cod_tra_invalida;
              end if ;
           else
              -- cambio el estado del contrato de cambio
              -- CR: se agrega cta_ref_contra3 y mto_contra3 para sumarizar límite de operaciones
              Update lc_ope_pendientes lc
                 set lc.liquidado = 'S',
                     lc.cod_usu_liquidacion = user,
                     lc.fec_liquidacion = sysdate,
                     lc.cta_ref_contra3 = v_nro_cta_debito,
                     lc.mto_contra3     = v_mto_debito
               where lc.nro_operacion = v_nro_operacion;
             -- Notificacion al debito
              BEGIN
                 v_res_notificacion:=PAW_NOT.fu_not_transferencias(v_nro_cta_debito, v_monto, v_cod_mon_debito, 'D', v_fec_valor);
              EXCEPTION
                 WHEN OTHERS THEN
                    NULL;
              END;
              --Notificacion al credito
              BEGIN
                 v_res_notificacion:=PAW_NOT.fu_not_transferencias(v_nro_cta_credito, v_mto_credito, v_cod_mon_credito, 'C', v_fec_valor);
              EXCEPTION
                 WHEN OTHERS THEN
                    NULL;
              END;                 
           end if;
        else
           -- hubo error en el débito
           if v_cod_respuesta = paw_bce.v_cod_aprobado then
              v_cod_respuesta := paw_bce.v_cod_tra_invalida;
           end if ;
        end if ;
     end if;
  end if;
  
  -- registro del movimiento
  lp_reg_operacion(v_nro_cta_debito /*p_nro_cuenta*/,
                   v_cod_mon_debito /*p_cod_moneda */,
                   v_monto          /*p_monto*/,
                   v_nro_cta_credito /*p_nro_cta_contra*/,
                   v_res_notificacion/*p_cantidad*/,
                   'Tipo_Ope_Cambios'/*p_etiqueta*/,
                   v_tip_operacion   /*p_dato*/,
                   'Cotizacion'      /*p_etiqueta2*/,
                   v_cotizacion      /*p_dato2*/,
                   null              /*observacion*/,
                   v_dir_ip          /*direccion IP*/);
  -- no se responde nada, solo la cantidad de firmas 000, solo se debe setear el v_cod_respuesta
  return lf_for_number('0',3)||lf_for_number(v_nro_operacion,15);
end;
-- fin de 214-confirmación de transferencia con contrato de cambio

-- 219 - Cambiar Clave transaccional
function fu_pro_operacion_219(p_parametros in varchar2) 
  return varchar2 is
v_cla_actual  varchar2(100);
v_cla_nueva   varchar2(100);
v_clave       varchar2(300);
v_aux         varchar2(100);
begin
  --valida clave de acceso
  pr_val_clave(p_parametros); 
  
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    -- obtenemos los parámetros de las variables
    v_cla_actual := substr( p_parametros,66,32);
    v_cla_nueva := substr( p_parametros,98,32);
    -- validamos la clave transaccional actual  
    v_cod_respuesta := lf_obt_cla_validar(v_cla_actual, v_cod_persona, v_cod_per_empresa, 0, 'T');
    -- se verifica que sea válida la clave transaccional ingresada
    if v_cod_respuesta = paw_bce.v_cod_aprobado then
      if v_cla_actual = v_cla_nueva then
        v_cod_respuesta := paw_bce.v_cla_ope_invalida;
      end if;
    end if;    
     -- si es clave nueva debe cambiar
    if v_cod_respuesta = paw_bce.v_cla_ope_cambiar then
      v_cod_respuesta := paw_bce.v_cod_aprobado;
    end if;
    -- no hubo errores hasta aquí    
    if v_cod_respuesta = paw_bce.v_cod_aprobado then
      -- actualizo la nueva clave
      v_clave := fu_gen_ope_clave(v_cla_nueva, v_cod_persona, v_cod_per_empresa, 'A', 'T', v_aux);
      if v_clave in ('-5', '-3') then
        v_cod_respuesta := paw_bce.v_cla_ope_invalida;
      elsif v_clave = '-6' then
        v_cod_respuesta := paw_bce.v_sol_cla_existe;
      end if;
    end if;
  end if;
  -- registro del movimiento
  lp_reg_operacion(null /*p_nro_cuenta*/,
                   null /*p_cod_moneda */,
                   null /*p_monto*/,
                   null /*p_nro_cta_contra*/,
                   null /*p_cantidad*/,
                   'Clave Nueva' /*p_etiqueta*/,
                   'Transaccional' /*p_dato*/
                   );  
  return '';
exception
  when others then
    v_cod_respuesta := paw_bce.v_cla_ope_invalida;
    return '01';
end;
   
   FUNCTION fu_pro_operacion_220(p_parametros IN VARCHAR2) RETURN VARCHAR2 IS
      v_retorno         VARCHAR2(650) := '00';
      v_cod_moneda      VARCHAR2(3);
      v_descripcion     VARCHAR2(35);
      
      -- 30/03/2012 - se agrega v_mon_local para usar solo una vez la funcion PAG_GEN.FU_OBT_MON_LOCAL
      v_mon_local GE_PAR_GENERALES.COD_MON_LOCAL%TYPE := PAG_GEN.FU_OBT_MON_LOCAL;
      CURSOR mon_cur IS
      -- 29/03/2012: CR, modificado para que traiga primero la moneda local y luego la 
      --     moneda extranjera
         SELECT fue_obt_des_moneda(v_mon_local) descripcion, v_mon_local cod_moneda, 'S'
           FROM DUAL
         UNION
         SELECT DISTINCT (m.descripcion) descripcion, m.cod_moneda cod_moneda, 'N'
           FROM cr_piz_montos p, ba_monedas m
          WHERE m.cod_moneda = p.cod_moneda
            AND p.cod_modalidad IN (41, 31)
            AND m.cod_moneda <> v_mon_local
         ORDER BY 3 DESC;
     -- 
   BEGIN
      -- 0. obtengo los datos del cliente
      v_cod_persona     := TRIM(substr(p_parametros,33,16));
      v_cod_per_empresa := TRIM(substr(p_parametros,50,15));
      
      -- 1. verifico el perfil del cliente
      IF v_cod_per_empresa IS NOT NULL THEN
         select cod_perfil
           into v_cod_perfil
           from ba_vinculos
          where cod_persona = v_cod_per_empresa
            and cod_perfil is not null
            and cod_per_vinculo = v_cod_persona;
                 
         if v_cod_perfil is null then
            v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;         
         end if;
      ELSE
         select a.cod_perfil
           into v_cod_perfil
           from ge_clientes a
          where a.cod_persona = v_cod_persona;
      END IF;
      
      -- 2. verifico si tiene permiso
      IF v_cod_respuesta = paw_bce.v_cod_aprobado then
         v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '039');
         IF instr(nvl(v_permiso,'x'),'I') = 0 AND instr(v_tip_mensaje,'I') > 0 THEN
            v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
         END IF;
      END IF;
      
      -- 3. Obtengo las monedas del cliente
      FOR t IN mon_cur LOOP
         v_cod_moneda  := lf_for_char(t.cod_moneda, 3);
         v_descripcion := lf_for_char(t.descripcion, 35);
         v_retorno     := v_retorno || v_cod_moneda || v_descripcion;
      END LOOP;

      RETURN lf_for_char(v_retorno, 640);
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         v_cod_respuesta := paw_bce.v_cod_dat_invalido;
         RETURN '01';
      WHEN OTHERS THEN
         RETURN '01';
   END;
    
-- 224 - Verificación de estado de clave transaccional  
function fu_pro_operacion_224(p_parametros in varchar2) return varchar2 is
  v_est_clave VARCHAR2(1);
begin
  v_cod_respuesta := paw_bce.v_cod_aprobado;
  --valida clave de acceso
  pr_val_clave(p_parametros);
  -- verificar ultima fecha de uso y ultima fecha de cambio de la clave transaccional
  lp_act_est_ope_clave(v_cod_persona, v_cod_per_empresa, 'T');
  if v_cod_respuesta in (paw_bce.v_cod_sin_autorizacion, paw_bce.v_cod_aprobado) then
    BEGIN
      v_cod_respuesta := paw_bce.v_cod_aprobado;
      select est_clave
        into v_est_clave
        from bw_ope_claves
       where cod_persona = v_cod_persona
         and tip_clave = 'T'
         and (
              (v_cod_per_empresa is null and cod_per_vinculada is null) or 
              (v_cod_per_empresa is not null and cod_per_vinculada = v_cod_per_empresa)
             );
    EXCEPTION
      WHEN TOO_MANY_ROWS THEN
        null;
      WHEN NO_DATA_FOUND THEN
        v_cod_respuesta := paw_bce.v_cla_solicitar;
    END;
    if (v_est_clave = 'A') then
      v_cod_respuesta := paw_bce.v_cla_cambiar;
    end if;
    if (v_est_clave = 'X') then
      v_cod_respuesta := paw_bce.v_cod_pin_bloqueado;
    end if;   
    if (v_est_clave = 'B') then
      v_cod_respuesta := paw_bce.v_cla_ope_intentos;
    end if;
  end if;
  return '';
end;
-- Fin de 224 - Verificación de estado de clave transaccional
-- 225- Consulta de Histórico de Pago a Proveedores
function fu_pro_operacion_225(p_parametros in varchar2)
  return clob is
v_cod_ente         ge_entes.cod_ente%type; -- código del ente
v_can_detalles     number(10) := 0;        -- cantidad de cuentas
v_fec_inicial      varchar2(10);           -- fecha inicial
v_fec_final        varchar2(10);           -- fecha final
v_fec_desde        date;
v_fec_hasta        date;
v_cta_beneficiario varchar2(15);           -- cta. o nombre del beneficiario
v_detalles         clob := null;           -- datos de las cuentas
v_det_temporal     long := null;           -- para cargar los datos en forma temporal
-- movimientos de pago a proveedores por ente
cursor c_mov_proveedores(p_cod_ente         in ge_entes.cod_ente%type,                          
                         p_fec_desde        in ge_pag_proveedores.fec_pago%type, 
                         p_fec_hasta        in ge_pag_proveedores.fec_pago%type,
                         p_cta_beneficiario in varchar2) is
    select gp.nro_cta_credito,gp.cod_moneda, gp.fec_pago, gp.monto,
           gp.referencia, gp.beneficiario, gp.cod_ente, gp.nro_factura
      from ge_pag_proveedores gp
     where gp.cod_ente = p_cod_ente
       and gp.estado = 'N'
       and gp.monto <> 0
       and 
       ( -- para buscar por cta. crédito o beneficiario
         p_cta_beneficiario is null 
         or gp.nro_cta_credito = p_cta_beneficiario 
         or lower(gp.beneficiario) like '%'||lower(p_cta_beneficiario)||'%'
       )
       and gp.fec_pago >= p_fec_desde
       and gp.fec_pago <= p_fec_hasta
  order by gp.fec_pago desc;
begin 
  --0. Valido la clave de acceso
  pr_val_clave(p_parametros);
  
  --1. Verifico si el cliente con su perfil tendrá acceso a realizar la consulta
  if v_cod_respuesta = paw_bce.v_cod_aprobado then
    v_permiso := lf_obt_permisos(nvl(v_cod_per_empresa,v_cod_persona), v_cod_perfil, '075');
    if v_permiso is null then
      v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
    end if;
  end if;
  
  --2. Obtengo el histórico de pagos
  if v_cod_respuesta = paw_bce.v_cod_aprobado then  
    begin
      -- obtenemos los parametros recibidos para búsqueda
      v_lugar := 'Obteniendo parametros';
      v_fec_inicial      := trim(substr(p_parametros,66,10));
      v_fec_final        := trim(substr(p_parametros,76,10));
      v_cta_beneficiario := trim(substr(p_parametros,86,15));
      BEGIN
        -- obtenemos la fecha inicial, por defecto 60 días
        v_lugar := 'Obteniendo fecha inicial';
        if v_fec_inicial is null  then
          v_fec_desde := paw_bce.v_fec_actual - 60;
        else
          v_fec_desde := to_date(v_fec_inicial, 'DD/MM/YYYY');
        end if ;      
        -- obtenemos la fecha final, por defecto fecha de hoy
        v_lugar := 'Obteniendo fecha final';
        if v_fec_final is null then
          v_fec_hasta := paw_bce.v_fec_actual;
        else
          v_fec_hasta := to_date(v_fec_final, 'DD/MM/YYYY'); 
        end if;
      EXCEPTION
        WHEN OTHERS THEN
          v_cod_respuesta := paw_bce.v_fec_invalida;
      END;
      -- la fecha inicial no puede exceder los 60 días
      if v_cod_respuesta = paw_bce.v_cod_aprobado and 
         (paw_bce.v_fec_actual - v_fec_desde) > 60 or 
         (paw_bce.v_fec_actual - v_fec_hasta) > 60 then
        v_cod_respuesta  := paw_bce.v_cod_err_permitido  /*'-88'*/;
      end if;
      -- se valida el rango de fechas
      if v_cod_respuesta = paw_bce.v_cod_aprobado and v_fec_hasta < v_fec_desde then
        v_cod_respuesta  := paw_bce.v_fec_invalida;
      end if ;
      -- el rango no puede exceder 60 días
      if v_cod_respuesta = paw_bce.v_cod_aprobado and (v_fec_hasta - v_fec_desde) > 60 then
        v_cod_respuesta  := paw_bce.v_fec_exceso;
      end if;
      -- las fechas son válidas, continuamos
      if v_cod_respuesta = paw_bce.v_cod_aprobado then
        -- obtenemos el código del ente para pago a proveedores
        v_lugar := 'Obteniendo codigo del ente';
        select ge.cod_ente
          into v_cod_ente
          from ge_entes ge
         where ge.cod_persona = nvl(v_cod_per_empresa, v_cod_persona)
           and ge.tipo = 'PR';
        -- armamos el detalle
        v_lugar := 'armando el detalle';
        for mv in c_mov_proveedores(v_cod_ente, v_fec_desde, v_fec_hasta, v_cta_beneficiario) loop
          v_can_detalles := v_can_detalles + 1;
          v_det_temporal := v_det_temporal||lf_for_char(mv.nro_cta_credito, 15)
                                          ||lf_for_char(mv.cod_moneda, 3)
                                          ||to_char(mv.fec_pago, 'dd/mm/yyyy')
                                          ||lf_for_money(mv.monto,18)
                                          ||lf_for_number(mv.referencia,10)
                                          ||lf_for_char(mv.beneficiario,60);
          if (v_can_detalles / 95) = trunc(v_can_detalles / 95) then
            v_detalles := v_detalles||v_det_temporal;
            v_det_temporal := null;
          end if;
        end loop;
        -- copiamos el temporal
        v_lugar := 'copiando el temporal';
        if v_det_temporal is not null then
          v_detalles := v_detalles||v_det_temporal;  
        end if;
      end if;
    exception
      when too_many_rows then
        v_cod_respuesta := paw_bce.v_cod_tra_invalida;
      when no_data_found then
        v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
      when others then 
        v_cod_respuesta := paw_bce.v_cod_otr_error;
    end;
  end if;
  v_lugar := 'retornando respuesta';
  return lf_for_number(v_can_detalles, 10)||(v_detalles);
exception
  when others then
     raise_application_error(-20005,sqlerrm||' En: '||v_lugar||' Cant.Reg '||v_can_detalles);
end;
-- fin de 225 Consulta de Histórico de Pago a Proveedores

end paw_bce;
/
