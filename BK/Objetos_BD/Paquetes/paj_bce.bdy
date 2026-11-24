create or replace package body it.paj_bce is
-----------***  FUNCIONES Y PROCEDIMIENTOS INTERNOS ***------------
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
   if v_can_conjunta > 0 then
      return 'S';
   else
      -- Obtengo el principal.
      Select cod_persona
        into v_cod_principal
        from ge_cta_clientes
       where nro_cuenta = p_nro_cuenta
         and relacion = 'P';
      --
      If pag_gen.FU_ES_PER_FISICA(v_cod_principal) = 'N' and v_cod_persona != v_cod_principal then
         return 'S';
      Else
         return 'N';
      End if;
   end if;
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
    If pag_gen.FU_ES_PER_FISICA(v_cod_principal) = 'N' and v_cod_persona != v_cod_principal then
       return 'S';
    Else
       return 'N';
    End if;
end;
-- devuelve el nro de tarjeta para una cuenta
function lf_obt_nro_tarjeta(p_nro_cuenta in varchar2)
   return varchar2 is
v_retorno varchar2(20);
begin
  select nro_tarjeta
    into v_retorno
    from ta_tarjetas
   where nro_cuenta = p_nro_cuenta
     and vigente = 'S'
     and cod_persona = v_cod_persona;
  return v_retorno;
exception
  when others then
      return null;
end;

-- devuelve el codigo del tipo de cuenta
function fu_tip_cuenta(p_cod_modulo in number,
                       p_cod_modalidad in number)
   return char is
v_cod_tip_cuenta char(2);
begin
  if p_cod_modulo = 3 then
     -- ahorros
     if p_cod_modalidad = 31 then
        v_cod_tip_cuenta := 'AH';
     elsif p_cod_modalidad in (32,33,34,36)    then
        v_cod_tip_cuenta := 'AP';
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
        v_cod_respuesta := paj_bce.v_cod_ped_duplicado;
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
         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, nvl(p_es_mov_noc,v_es_mov_noc));
    
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
begin

  if p_cod_modulo in (3,4) then
     -- cuentas pasivas
     pag_cta.pr_obt_cuenta(p_nro_cuenta);
     v_sal_actual := pag_cta.FU_SAL_DISPONIBLE;
  elsif p_cod_modulo = 5 then
     -- Tarjetas
    select nvl(b.sal_facturar,0)+
           nvl(b.sal_facturado,0)+
           nvl(b.sal_financiado,0)+
           nvl(b.sal_cuo_pendientes,0)
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
     v_cod_respuesta := paj_bce.v_cod_sis_cierre;
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

-- procedimientos de control de datos recibidos
procedure pr_val_caja  is
-- Verifico la situacion del numero de caja
v_est_caja varchar2(1);
Begin
   Select estado, tipo, cod_oficina, cod_usuario, fec_hor_cierre
     into v_est_caja, v_tip_caja, v_cod_ofi_origen, v_cod_usuario, v_ult_cierre
     from cj_cajas
     where nro_caja = to_number(paj_bce.v_nro_terminal);
   if v_tip_caja not in ('C','I','S') then
      -- tipo de caja no permitido
      paj_bce.v_cod_respuesta := '-20';
   end if;
   if v_est_caja <> 'A' then
      paj_bce.v_cod_respuesta := '-20';
   end if;
exception
   when no_data_found then
     paj_bce.v_cod_respuesta := '-20'; -- con error
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
        v_cod_respuesta := paj_bce.v_cod_cta_invalida;
     elsif v_est_cta_debito not in ('P','I','N') then
        v_cod_respuesta := paj_bce.v_cod_cta_invalida;
     elsif pag_cta.fu_ver_tra_prohibida(p_nro_cta_debito,p_cod_tra_padre, 9, 91) = 'S' then
        v_cod_respuesta := paj_bce.v_cod_tra_prohibida;
     elsif fu_es_conjunta(p_nro_cta_debito) = 'S' then
        v_cod_respuesta := paj_bce.v_cod_tra_invalida;
     elsif p_cod_mad_debito = 31 and pag_cta.fu_obt_cta_cte_comb(p_nro_cta_debito) is not null then
        v_cod_respuesta := paj_bce.v_cod_cta_invalida;
     else
        pag_cta.pr_ver_operacion(p_nro_cta_debito,p_cod_tra_padre,9,91,'D',p_cod_mon_debito, p_monto, v_cod_ofi_origen,
                                 p_cod_mod_debito, p_cod_mad_debito, v_nvo_estado, v_sal_disponible,
                                 v_procesa,503);
        if v_procesa = 'N' then
           -- no se puede debitar
           if instr(upper(pag_cta.G_MSJ_ERROR),'INSUFIC') > 0 then
              -- saldo insuficiente
              v_cod_respuesta := paj_bce.v_cod_sal_insuficiente;
           else
              v_cod_respuesta := paj_bce.v_cod_cta_invalida;
           end if;
        end if;
     end if;
exception
    when no_data_found then
       v_cod_respuesta  := paj_bce.v_cod_cta_inexistente;
    when too_many_rows then
       v_cod_respuesta  := paj_bce.v_cod_cta_duplicada;
    when others then
       v_cod_respuesta  := paj_bce.v_cod_cta_invalida;
end;

-- obtener cotizacion para operaciones via banca electronica
function lf_obt_cotizacion
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

/* convertir un monto de una moneda a otra */
procedure lp_con_mon_a_moneda
 (p_cod_mon_original in ba_monedas.cod_moneda%type
 ,p_cod_mon_destino in ba_monedas.cod_moneda%type
 ,p_mto_mon_original in number
 ,p_mto_mon_destino out number
 ,p_cot_mon_original in out number
 ,p_cot_mon_destino in out number
 )
 is
   v_lugar           varchar2(100);
   v_redondeo        number(5);
begin
    v_lugar := 'obtener moneda base';
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,p_cod_mon_destino);
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
       if  p_cod_mon_original <> v_cod_mon_local and p_cod_mon_destino = v_cod_mon_local then
           --convertir moneda original a base o destino
           p_cot_mon_original := nvl(p_cot_mon_original,lf_obt_cotizacion(p_cod_mon_original,'C'/*COMPRA*/));
           p_cot_mon_destino := 1;
           p_mto_mon_destino := round(p_mto_mon_original * p_cot_mon_original,v_redondeo);
       elsif p_cod_mon_original = v_cod_mon_local and p_cod_mon_destino <> v_cod_mon_local then
           -- pasar moneda original a moneda base
           p_cot_mon_original := 1;
           p_cot_mon_destino := nvl(p_cot_mon_destino,lf_obt_cotizacion(p_cod_mon_destino,'V'/*VENTA */));
           p_mto_mon_destino := round(p_mto_mon_original/p_cot_mon_destino,v_redondeo);
       elsif p_cod_mon_original <> v_cod_mon_local and p_cod_mon_destino <> v_cod_mon_local then
           p_cot_mon_original := nvl(p_cot_mon_original,lf_obt_cotizacion(p_cod_mon_original,'C'/*COMPRA*/));
           p_mto_mon_destino := p_mto_mon_original * p_cot_mon_original;
           p_cot_mon_destino := nvl(p_cot_mon_destino,lf_obt_cotizacion(p_cod_mon_destino,'V'/*VENTA */));
           p_mto_mon_destino := round(p_mto_mon_destino/p_cot_mon_destino,v_redondeo);
       end if;
   end if;
   exception
   when others then
      raise_application_error(-20000,v_lugar || ' - ' ||sqlerrm);
end;




-- Identificacion del cliente. Devuelve datos del cliente
procedure pr_val_clave(p_parametros in varchar2) is
-- variables
v_can_intentos    number(4) := 0; -- cantidad de intentos fallidos
v_clave           varchar2(10);   -- clave encriptada en la base
v_est_clave       varchar2(1);    -- estado de la clave: N-Nueva, A-Activa- B-bloqueada I_Inactiva
v_tip_clave       varchar2(1);    -- Tipo de clave
v_tip_consulta    varchar2(3) := substr(p_parametros,28,3);
v_dir_correo      varchar2(300);
v_tip_persona     varchar2(1);
begin
  -- 1. Asigno como valido al inicio
  v_cod_respuesta := paj_bce.v_cod_aprobado;
  -- 2. Desarmo los datos recibidos en parametros
  p_clave    := substr(p_parametros,1,10);           -- clave del cliente
  p_dato     := trim(substr(p_parametros,11,16));    -- Dato: nro de documento, cliente o cuenta
  p_tip_dato := nvl(trim(substr(p_parametros,27,1)),'C');  -- Tipo: D-Nro.Doc, C-Cuenta, K-Cod.cliente
  if p_tip_dato = 'C' and (instr(p_dato,'-') > 0 or instr(p_dato,' ') > 0) then
     -- se extrae los guiones de la cuenta
     If v_cod_operacion = '031' or (v_cod_operacion = '010' and v_tip_consulta = '031') then
        -- Si es pago de prestamos solo debe quitarle el guion y el espacio si tiene
        p_dato := trim(replace(replace(p_dato, '-',''), ' ',''));
     Else
        p_dato := to_number(substr(p_dato,7));
     End if;
  elsif length(p_dato) = 16 then
     -- es un tarjeta de credito, busco y reemplazo el dato
     declare
       v_nro_cta_tar varchar2(16);
     begin
        select a.nro_cuenta
          into v_nro_cta_tar
          from ge_cta_clientes a, ta_tarjetas b
         where b.nro_tarjeta = p_dato
           and b.nro_cuenta = a.nro_cuenta
           and b.cod_persona = a.cod_persona;
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
      select a.clave, b.nom_completo, a.est_clave, a.cod_usu_oficial, b.cod_persona, a.can_intentos,
             nvl(a.tip_clave,'C'), dir_correo
        into v_clave, v_nom_completo, v_est_clave, v_cod_usu_oficial, v_cod_persona, v_can_intentos,
             v_tip_clave, v_dir_correo
        from  ge_clientes a, ba_personas b
       where a.cod_persona = b.cod_persona
         and b.nro_documento = p_dato;
  elsif p_tip_dato in ('K') then -- codigo de cliente
      select a.clave, b.nom_completo, a.est_clave, a.cod_usu_oficial, b.cod_persona, a.can_intentos,
             nvl(a.tip_clave,'C'), dir_correo
        into v_clave, v_nom_completo, v_est_clave, v_cod_usu_oficial, v_cod_persona, v_can_intentos,
             v_tip_clave, v_dir_correo
        from  ge_clientes a, ba_personas b
       where a.cod_persona = b.cod_persona
         and b.cod_persona = p_dato;         
  elsif p_tip_dato = 'C' then -- por cuenta
      if v_cod_operacion in ('010','015','031','032') and p_clave = 'a010yzp89c' then
          -- es clave fija
          select a.clave, b.nom_completo, a.est_clave, a.cod_usu_oficial, b.cod_persona, a.can_intentos,
                 nvl(a.tip_clave,'C'), dir_correo
            into v_clave, v_nom_completo, v_est_clave, v_cod_usu_oficial, v_cod_persona, v_can_intentos,
                 v_tip_clave, v_dir_correo
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
                  select a.clave, a.est_clave, a.cod_usu_oficial, a.can_intentos, nvl(a.tip_clave,'C')
                    into v_clave, v_est_clave, v_cod_usu_oficial, v_can_intentos, v_tip_clave
                    from ge_clientes a
                   where a.cod_persona = v_cod_persona
                     and a.clave = p_clave;             
              else -- la cuenta es de una persona fisica
                  select a.clave, b.nom_completo, a.est_clave, a.cod_usu_oficial, b.cod_persona, a.can_intentos,
                         nvl(a.tip_clave,'C'), dir_correo
                    into v_clave, v_nom_completo, v_est_clave, v_cod_usu_oficial, v_cod_persona, v_can_intentos,
                         v_tip_clave, v_dir_correo
                    from  ge_clientes a, ba_personas b
                   where a.cod_persona = b.cod_persona
                     and a.clave = p_clave
                     and b.cod_persona in (select x.cod_persona
                                   from ge_cta_clientes x
                                  where x.nro_cuenta = p_dato
                                    and x.cod_persona = b.cod_persona)
                     and rownum = 1; -- primero que encuentre    
              end if;   
          exception
            when no_data_found then
                v_cod_respuesta := paj_bce.v_cod_pin_invalido;
          end;
      end if;
  else  -- error de tipo de
      v_cod_respuesta := paj_bce.v_cod_cta_inexistente;
  end if;
  exception
     when no_data_found then
        v_cod_respuesta := paj_bce.v_cod_cta_inexistente;
     when too_many_rows then
        v_cod_respuesta := paj_bce.v_cod_pin_inexistente;
  end;
  -- 4. Veo la clave si la clave recibida corresponde a la actual
  if v_cod_respuesta in (paj_bce.v_cod_aprobado, paj_bce.v_cod_pin_invalido) then
     if nvl(v_clave,'-1') <> nvl(p_clave,'-8') then
        if v_cod_operacion in ('010','015','031','032') and p_clave = 'a010yzp89c' then
           -- caso especial, es un deposito o pago sin PIN, se toma como valido
           v_cod_respuesta := paj_bce.v_cod_aprobado;
        else
           -- pin invalido
           if v_can_intentos > 1 then
              v_est_clave := 'B'; -- Bloquear la clave
              v_cod_respuesta := paj_bce.v_cod_pin_bloqueado;
           else
              v_cod_respuesta := paj_bce.v_cod_pin_invalido;
           end if;
           -- actualizo la cantidad de intentos fallidos y estado si cambia
           update ge_clientes a
              set a.can_intentos = nvl(a.can_intentos,0) + 1,
                  fec_est_clave = decode(v_est_clave,est_clave,fec_est_clave,sysdate),
                  est_clave = nvl(v_est_clave,est_clave)
            where cod_persona = v_cod_persona;
            if v_dir_correo is not null and v_est_clave = 'B' then
                it_mail.mail(fug_obt_dir_correo,
                       v_dir_correo,
                      'Bloqueo de su PIN(Clave de acceso)',
                      'Sr. Cliente: '|| chr(10) ||chr(10) ||
                      'Le informamos que su Clave de acceso al Regional Web y Autoservicios ha  sido' || chr(10) ||
                      'bloqueada temporalmente debido a mas de 3 intentos fallidos de ingreso con una' || chr(10) ||
                      'Clave incorreta(PIN). '  || chr(10) ||chr(10) ||
                      'Para desbloquear su PIN, debera acercarse hasta cualquier Agencia o informar a'   || chr(10) ||
                      'su Oficial de Negocios via telefonica.' || chr(10) || chr(10) ||
                      'Atentamente. '
                      );
            end if;
           commit;
        end if;
     elsif v_est_clave = 'B' then
        v_cod_respuesta := paj_bce.v_cod_pin_bloqueado;
     elsif v_cod_operacion in ('030','031','032','033','060','070', '075','082') and v_tip_clave = 'C' then
        -- es una clave solo de consulta y esta tratando de hacer transacciones
        v_cod_respuesta := paj_bce.v_cod_sin_autorizacion;
     elsif v_cod_operacion in ('011') and v_tip_consulta in ('060', '030', '031', '032', '070', '075', '082') and v_tip_clave = 'C' then
        -- Debe verificar el tipo de consulta para verificar si tiene o no autorizacion.
        v_cod_respuesta := paj_bce.v_cod_sin_autorizacion;
     elsif v_est_clave IN ('N','M') then -- clave nueva o modificada, cambiar
        v_cam_clave := 'S';
     else
        -- PIN valido, se inicializa el bloqueo
        update ge_clientes
           set can_intentos = 0
         where cod_persona = v_cod_persona
           and nvl(can_intentos,0) != 0;
        commit;
     end if;
  end if;
end;
--- fin de la validacion de la clave

----------------********** OPERACIONES PARTICULARES **********------------------------
-- Sincronizacion. Devuelve la fecha y hora
function fu_pro_operacion_000(p_parametros in varchar2)
  return varchar2 is
begin
  -- Retorna la fecha y hora en el formato:
  -- FECHA	Fecha del Servidor: formato ddmmyyyy		D	8
  -- HORA	Hora del Servidor: formato hhmmss		      C	8
   return to_char(sysdate,'ddmmyyyyhh24miss');
end;
-- fin de la sincronizacion

-- Identificacion del cliente. Devuelve datos del cliente
function fu_pro_operacion_005(p_parametros in varchar2)
  return varchar2 is
-- datos a responder
v_nom_oficial  varchar2(50);  -- nombre del oficial del cliente
v_tel_oficial  varchar2(10);  -- telefono del oficial
v_cor_oficial  varchar2(80);  -- correo email del oficial
v_dir_ip       varchar2(20);
v_observacion varchar2(1000);
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. cargo los datos del oficial, si es valido
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     begin
        select substr(u.nombre,1,50), substr(u.telefono,1,10), u.dir_correo
          into v_nom_oficial, v_tel_oficial, v_cor_oficial
          from ba_usuarios u
         where cod_usuario = v_cod_usu_oficial;
     exception
        when others then
           v_cod_respuesta  := paj_bce.v_cod_otr_error;
     end;
  end if;
  If length(p_parametros) > 27 then
     v_dir_ip := replace(trim(substr(p_parametros, 28, length(p_parametros)-27)), chr(13),'');
     If v_dir_ip is not null then
       -- Si tengo la direcci?n ip debo guardar en el log.
       insert into ge_mov_bca_electronica
         (fecha, hora, nro_caja, nro_operacion, 
          cod_operacion, dir_ip, 
          tip_dato, dato, clave, cod_respuesta, 
          cod_persona, observacion)
       values
         (trunc(sysdate), to_char(sysdate, 'hh24:mi:ss'),
          v_nro_terminal, v_nro_operacion, v_cod_operacion,
          v_dir_ip, 
          nvl(trim(substr(p_parametros,27,1)),'C'), trim(substr(p_parametros,11,16)), substr(p_parametros,1,10),
          v_cod_respuesta, v_cod_persona,
          v_observacion);
       commit;
     end if;
  End if;

  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return v_cam_clave||
            lf_for_char(v_nom_completo,100)||
            lf_for_char(v_nom_oficial,50)||
            lf_for_char(v_tel_oficial,10)||
            lf_for_char(v_cor_oficial,80)||
            lf_for_char(lf_obt_mensaje(v_cod_persona),300);
  else
     return null;  -- nada
  end if;
end;
--- fin de la identificacion del cliente

-- Validacion de cuentas/tarjetas para depositos o pagos con o sin clave
function fu_pro_operacion_010(p_parametros in varchar2)
  return varchar2 is
-- datos recibidos
v_tip_consulta   varchar2(3) := substr(p_parametros,28,3);   -- tipo de consulta
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
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. cargo los datos del oficial, si es valido
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     begin
         select substr(u.nombre,1,50), substr(u.telefono,1,10), u.dir_correo
          into v_nom_oficial, v_tel_oficial, v_cor_oficial
          from ba_usuarios u
         where cod_usuario = v_cod_usu_oficial;
     exception
        when others then
           v_cod_respuesta  := paj_bce.v_cod_otr_error;
     end;
  end if;
  -- 3. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     begin
        select a.nro_cuenta,
               fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina,a.nro_cuenta, a.cod_moneda),
               fu_tip_cuenta(a.cod_modulo, a.cod_modalidad),
               fug_obt_des_modal(a.cod_modulo,a.cod_modalidad),
               a.cod_moneda, a.denominacion, a.estado, cod_modalidad,
               cod_modulo
          into v_nro_cuenta,v_cta_formateada, v_cod_tip_cuenta,
               v_des_tip_cuenta, v_cod_moneda, v_nom_cuenta,
               v_est_cuenta, v_cod_mad_cta, v_cod_mod_cta
          from ge_cuentas a
         where a.nro_cuenta = p_dato; -- contiene el nro de cuenta
      -- v_tip_consulta: 015=Deposito, 031=Prestamos, 032=Tarjetas
      if v_cod_mod_cta = 5 then
         v_cta_formateada := lf_obt_nro_tarjeta(v_nro_cuenta);
      end if;
      if v_tip_consulta = '015' then
         -- deposito
         if v_cod_mad_cta not in (31,41) then
            v_cod_respuesta := paj_bce.v_cod_cta_invalida;
         elsif v_est_cuenta not in ('A','I','N','S') then
            v_cod_respuesta := paj_bce.v_cod_cta_invalida;
         elsif pag_cta.fu_ver_tra_prohibida(v_nro_cuenta,393, 9, 91) = 'S' then
            v_cod_respuesta := paj_bce.v_cod_tra_prohibida;
         elsif v_cod_mad_cta = 31  and pag_cta.fu_obt_cta_cte_comb(p_dato) is not null then
            v_cod_respuesta := paj_bce.v_cod_cta_invalida;
         end if;
      elsif v_tip_consulta = '031' then
         -- pago de prestamos
         if v_cod_mod_cta <> 6 then
            v_cod_respuesta := paj_bce.v_cod_cta_invalida;
         elsif v_est_cuenta in ('N') then -- cancelada
            v_cod_respuesta := paj_bce.v_cod_cta_cancelada;
         end if;
      elsif v_tip_consulta = '032' then
         -- pago de tarjetas
         if v_cod_mod_cta <> 5 then
            v_cod_respuesta := paj_bce.v_cod_cta_invalida;
         elsif v_est_cuenta in ('C') then -- cancelada
            v_cod_respuesta := paj_bce.v_cod_cta_cancelada;
         end if;
      end if;

     exception
        when no_data_found then
           v_cod_respuesta  := paj_bce.v_cod_cta_inexistente;
        when too_many_rows then
           v_cod_respuesta  := paj_bce.v_cod_cta_duplicada;
        when others then
           v_cod_respuesta  := paj_bce.v_cod_cta_invalida;
     end;
  end if;
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return lf_for_char(v_cta_formateada,17)||
            lf_for_char(v_cod_tip_cuenta,2)||
            lf_for_char(v_des_tip_cuenta,35)||
            lf_for_char(rpad(v_cod_moneda,3,'.'),3)||
            lf_for_char(v_nom_cuenta,100)||
            lf_for_char(v_nom_oficial,50)||
            lf_for_char(v_tel_oficial,10)||
            lf_for_char(v_cor_oficial,80);
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
v_tip_consulta   varchar2(3) := substr(p_parametros,28,3);   -- tipo de consulta
v_ver_cuentas    varchar2(1) := substr(p_parametros,31,1);   -- ver solo cuentas de debito, credito o todas
-- datos a responder
v_can_detalles   number(3);     -- cantidad de cuentas
--
v_detalles       clob := null; -- datos de las cuentas
v_despliega      varchar2(1);  -- indica si la cuenta debe o no desplegarse
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
     and b.cod_persona = v_cod_persona
     and a.cod_modulo = c.cod_modulo
     and a.cod_modalidad = c.cod_modalidad
     and a.estado = c.estado
     and b.cod_modulo != 7
     and c.activo = 'S'  -- solo cuentas activas
     and a.estado <> 'X' -- pendiente de verificacion
     and (p_cod_moneda is null or a.cod_moneda = p_cod_moneda)
   order by decode(b.cod_modalidad,31,1,
                   decode(b.cod_modulo,5,2,
                          decode(b.cod_modalidad,33,3,34,4,
                                 decode(b.cod_modulo,4,5,6))));

Cursor entes is 
      -- Se utiliza para validar pago de Sueldos
      select cod_ente, descripcion
        from ge_entes a
       where a.cod_persona = v_cod_persona
         and a.tipo = 'SU'
         and fug_obt_parentes(a.cod_ente,'SER_ACTIVO') = 'S'
         and fug_obt_parentes(a.cod_ente,'HAB_HOMEBANKING') = 'S';   
Cursor provee is 
      -- Se utiliza para validar pago a proveedores
      select cod_ente, descripcion, 
             fug_obt_parentes(a.cod_ente,'REF_TXT_PPROV') formato
        from ge_entes a
       where a.cod_persona = v_cod_persona
         and a.tipo = 'PR'
         and fug_obt_parentes(a.cod_ente,'SER_ACTIVO_PRV') = 'S'
         and fug_obt_parentes(a.cod_ente,'HAB_HOMEBANKING_PRV') = 'S';                                        
begin
  if p_ver_cuentas is not null then
     -- viene como cuentas de debito directo
     v_ver_cuentas := p_ver_cuentas;
  else
     -- 1. valido la clave del cliente
     pr_val_clave(p_parametros);
  end if;
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
                   where a.cod_persona = v_cod_persona
                     and a.tipo = 'SU'
                     and fug_obt_parentes(a.cod_ente,'SER_ACTIVO') = 'S'
                     and fug_obt_parentes(a.cod_ente,'HAB_HOMEBANKING') = 'S';
                  v_despliega := 'N';
                  -- Si existe verifico cuantas cuentas posee.
                  If v_can_detalles > 0 then   
                     for re in entes Loop
                          v_detalles :=  v_detalles ||
                            lf_for_char(re.cod_ente,5)||
                            lf_for_char(re.descripcion,60);
                     end loop;              
                  else
                     v_cod_respuesta := paj_bce.v_cod_sin_autorizacion;
                  end if;   
               exception
                  when too_many_rows then
                      v_cod_respuesta := paj_bce.v_cod_cta_duplicada;
                  when others then
                      v_cod_respuesta := paj_bce.v_cod_sin_autorizacion;
               end;
           elsif (v_tip_consulta in ('075')) then -- Pago a Proveedores
               begin
                  select count(*) 
                    into v_can_detalles
                    from ge_entes a
                   where a.cod_persona = v_cod_persona
                     and a.tipo = 'PR'
                     and fug_obt_parentes(a.cod_ente,'SER_ACTIVO_PRV') = 'S'
                     and fug_obt_parentes(a.cod_ente,'HAB_HOMEBANKING_PRV') = 'S';
                  v_despliega := 'N';
                  -- Si existe verifico cuantas cuentas posee.
                  If v_can_detalles > 0 then   
                     for re in provee Loop
                          v_detalles :=  v_detalles ||
                            lf_for_char(re.cod_ente,5)||
                            lf_for_char(re.descripcion,60)||
                            lf_for_char(re.formato, 30);
                     end loop;              
                  else
                     v_cod_respuesta := paj_bce.v_cod_sin_autorizacion;
                  end if;   
               exception
                  when too_many_rows then
                      v_cod_respuesta := paj_bce.v_cod_cta_duplicada;
                  when others then
                      v_cod_respuesta := paj_bce.v_cod_sin_autorizacion;
               end;
           end if;
        elsif (v_ver_cuentas in ('D','C') and ct.cod_modalidad in (31,41)) then
           if ct.cod_modalidad = 31 and pag_cta.fu_obt_cta_cte_comb(ct.nro_cuenta) is not null then
              v_despliega := 'N';
           else
               if v_ver_cuentas = 'D' then
                  -- veo si la cuenta no es conjunta
                  if fu_es_conjunta(ct.nro_cuenta) = 'S' or ct.estado in ('X','A','T','D','C') then
                     v_despliega := 'N';
                  else
                     v_despliega := 'S';
                  end if;
               else
                  v_despliega := 'S';
               end if;
           end if;
        elsif v_tip_consulta in ('031', '032') then
           if v_tip_consulta = '032' then -- pago de tarjetas
              if  ct.cod_modulo = 5  then
                  v_despliega := 'S';
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
         v_cod_respuesta  := paj_bce.v_cod_cta_inexistente;
     end if;
  end if;
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
v_nro_sobre       number(10)   := to_number(trim(substr(p_parametros,28,10)));   -- sobre
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
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     begin
        select a.nro_cuenta, a.cod_moneda, a.estado, cod_modalidad,
               cod_modulo, cod_oficina
          into v_nro_cuenta, v_cod_moneda,
               v_est_cuenta, v_cod_mad_cta, v_cod_mod_cta, v_cod_ofi_cta
          from ge_cuentas a
         where a.nro_cuenta = p_dato; -- contiene el nro de cuenta
         -- deposito
         if v_cod_mad_cta not in (31,41) then
            v_cod_respuesta := paj_bce.v_cod_cta_invalida;
         elsif v_est_cuenta not in ('A','I','N','S') then
            v_cod_respuesta := paj_bce.v_cod_cta_invalida;
         elsif pag_cta.fu_ver_tra_prohibida(v_nro_cuenta,393, 9, 91) = 'S' then
            v_cod_respuesta := paj_bce.v_cod_tra_prohibida;
         end if;
     exception
        when no_data_found then
           v_cod_respuesta  := paj_bce.v_cod_cta_inexistente;
        when too_many_rows then
           v_cod_respuesta  := paj_bce.v_cod_cta_duplicada;
        when others then
           v_cod_respuesta  := paj_bce.v_cod_cta_invalida;
     end;
     if v_cod_respuesta = paj_bce.v_cod_aprobado then
        -- esta la cuenta en condiciones, verifico el horario del deposito
        lp_ver_horario;
        -- verifico la validez de los montos
        begin
          v_imp_efectivo  := nvl(to_number(replace(trim(substr(p_parametros,38,18)),',','.')),0);   -- efectivo
          v_imp_che_n_bco := nvl(to_number(replace(trim(substr(p_parametros,56,18)),',','.')),0);  -- che.ntro.bco
          v_imp_che_o_bco := nvl(to_number(replace(trim(substr(p_parametros,74,18)),',','.')),0);  -- che otros bcos.
          v_tot_deposito  := nvl(to_number(replace(trim(substr(p_parametros,92,18)),',','.')),0);   -- total
          if v_cod_moneda = v_cod_mon_local then
             if v_imp_efectivo <> trunc(v_imp_efectivo) or
                v_imp_che_n_bco <> trunc(v_imp_che_n_bco) or
                v_imp_che_o_bco <> trunc(v_imp_che_o_bco) then
               -- monto con decimales y en guaranies no permite
               v_cod_respuesta := paj_bce.v_cod_mto_invalido;
             elsif nvl(v_imp_efectivo,0) + nvl(v_imp_che_n_bco,0) +
                   nvl(v_imp_che_o_bco,0) <> nvl(v_tot_deposito,0) then
                   -- total depositado invalido
                   v_cod_respuesta := paj_bce.v_cod_tot_invalido;
             end if;
          end if;
        exception
          when others then
             -- monto invalido
             v_cod_respuesta := paj_bce.v_cod_mto_invalido;
        end;
        if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
                v_cod_respuesta := paj_bce.v_cod_cta_invalida;
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
                v_cod_respuesta := paj_bce.v_cod_cta_invalida;
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
                v_cod_respuesta := paj_bce.v_cod_cta_invalida;
                return null;
             end if;

          end if;
          if sql%notfound then
             -- no se encontro registro de actualizacion
             v_cod_respuesta := paj_bce.v_cod_cta_inexistente;
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
              v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
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
              v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
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
              v_cod_tra_padre   := 395;
              v_cod_transaccion := 615;
              v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
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
                                 'O', -- cheque otros bcos
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
  -- no se responde nada, solo se debe setear el v_cod_respuesta
  return null;
end;
-- fin de 015-confirmacion de deposito en cuenta

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
      and fec_insercion > v_ult_cierre;
   -- 2. actualizo la fecha de cierre
   v_ult_cierre := sysdate;
   update cj_cajas
      set fec_hor_cierre = v_ult_cierre
    where nro_caja = to_number(paj_bce.v_nro_terminal);
   commit;
   -- retorno la cantidad de sobres
   return lf_for_number(v_can_sobres,4);
end;
-- Fin del cierre

-- Devuelve el saldo detallado de las cuentas
function fu_pro_operacion_020(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_ver_todas      varchar2(3) := substr(p_parametros,28,1);   -- ver todas las cuentas s/n
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

v_val_tasa        number(10,4) := null;
v_fec_inicio      date;
v_fec_vencimiento date;
v_dia_mora        number;
v_che_devuelto    varchar2(01);
v_can_cuotas      number(5);
--
v_cta_formateada varchar2(17);

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
     and b.cod_persona = v_cod_persona
     and a.cod_modulo = c.cod_modulo
     and a.cod_modalidad = c.cod_modalidad
     and a.estado = c.estado
     and b.cod_modulo != 7
     and c.activo = 'S'  -- solo cuentas activas
     and a.estado <> 'X' -- pendiente de verificacion
     and (v_ver_todas = 'S' or b.nro_cuenta = p_dato) -- solo ve la cuenta recibida o todas
   order by decode(b.cod_modalidad,31,1,
                   decode(b.cod_modulo,5,2,
                          decode(b.cod_modalidad,33,3,34,4,
                                 decode(b.cod_modulo,4,5,6))));
cursor cuotas(p_nro_cuenta in varchar2) is
  select  nro_cuota,
          nvl(sal_capital,0) + nvl(sal_interes,0) + nvl(sal_int_documentado,0) mto_cuota,
          fec_vencimiento, fec_ult_pago,
          decode(sign(v_fec_actual - fec_vencimiento),1,
                 (v_fec_actual-fec_vencimiento), 0 ) dia_mora
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
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
                      val_tasa, fec_inicio, fec_vencimiento, dia_atraso,
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
                      nvl(sal_pag_minimo,0),
                      nvl(lin_credito,0),
                      tas_financiacion,
                      fec_ult_cierre,
                      fec_vct_ult_cierre,
                      dia_mora,
                      'N',
                      lin_cuotas
                 into v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa,
                      v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto,
                      v_monto5
                 from ta_cta_tarjetas
                where nro_cuenta = ct.nro_cuenta;

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
              v_cod_respuesta := paj_bce.v_cod_cta_inexistente;
         end;
         if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
     end loop;
     if v_can_detalles = 0 then
        -- no tiene detalles
         v_cod_respuesta  := paj_bce.v_cod_cta_inexistente;
     end if;
  end if;
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
-- fin de la 020 - Saldo detallado de cuentas

-- 021 Movimientos por cuenta
function fu_pro_operacion_021(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_can_dias       number(3)   := substr(p_parametros,28,2);   -- cantidad de dias
v_ver_todas      varchar2(3) := substr(p_parametros,30,1);   -- ver todas las cuentas s/n
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
v_can_movimientos number(6);
v_saldo           number(18,2) := 0;
v_fec_inicio      date := to_date('01'||to_char(v_fec_actual-1,'mmyyyy'),'ddmmyyyy');
v_can_limite      number(8) := 50;
v_fec_insercion   date;
v_det_temporal    long; -- esto es para ir cargando los datos en forma temporal
v_nro_secuencia   number(6);

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
     and b.cod_persona = v_cod_persona
     and a.cod_modulo = c.cod_modulo
     and a.cod_modalidad = c.cod_modalidad
     and a.estado = c.estado
     and c.activo = 'S'  -- solo cuentas activas
     and a.estado <> 'X' -- pendiente de verificacion
     and b.cod_modalidad in (31,41)
     and (v_ver_todas = 'S' or b.nro_cuenta = p_dato); -- solo ve la cuenta recibida o todas
-- movimientos por cuenta
cursor movimientos(p_nro_cuenta in varchar2) is
  select fecha, fec_valor, nro_documento, des_tra_padre, decode(v_nro_terminal,'999', replace(a.hora, ':', ''), abr_tra_padre) abr_tra_padre,
         cod_tip_movimiento, monto, hora, nro_secuencia, a.fec_insercion
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
   order by a.fec_insercion desc, nro_secuencia desc;
cursor movimientos2(p_nro_cuenta in varchar2, p_fec_insercion date, p_nro_secuencia in number) is
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
   order by a.fec_insercion, nro_secuencia; 

begin
  -- 0. Inicializo el campo can_dias
  if nvl(v_can_dias,0) <= 0 then
     v_can_dias := 7;
  end if;
  if v_nro_terminal = '999' then
     v_can_limite :=  640;  -- temporalmente, debe ser 999 RAMG
  end if;
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     v_can_detalles := 0;
     for ct in cuentas loop
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

/*            if ct.cod_modalidad = 31 then -- ahorro vista
               select nvl(sal_total,0) - nvl(sal_retenido,0)-
                      nvl(sal_bloqueado,0),
                      nvl(sal_retenido,0)
                 into v_monto2, v_monto3
                 from ah_cta_vistas
                where nro_cuenta = ct.nro_cuenta;
            elsif ct.cod_modalidad = 41 then -- cuenta corriente
               select nvl(sal_total,0) - nvl(sal_retenido,0)-
                      nvl(sal_bloqueado,0),
                      nvl(sal_retenido,0)
                 into v_monto2, v_monto3
                 from cc_cta_corrientes
                where nro_cuenta = ct.nro_cuenta;
            end if;*/
         exception
            when others then
              v_cod_respuesta := paj_bce.v_cod_cta_inexistente;
         end;
         v_det_movimientos := null;
         --V_monto1 = al saldo disponible de la cuenta pero sin considerar el Bloqueado 
         --Saldo disponibles + el Saldo bloqueado que resto en el package  
         v_monto1 := pag_cta.g_ctas.sal_disponible + pag_cta.g_ctas.sal_bloqueado; 
         v_can_movimientos := 0;
         -- primer ciclo solo para obtener el monto 1
         for mv in movimientos(ct.nro_cuenta) loop
               if mv.cod_tip_movimiento = 'C' then
                  v_monto1 := nvl(v_monto1,0) - nvl(mv.monto,0);
               else
                  v_monto1 := nvl(v_monto1,0) + nvl(mv.monto,0);
               end if;
               v_can_movimientos := v_can_movimientos + 1;
               v_fec_insercion := mv.fec_insercion;
               v_nro_secuencia := mv.nro_secuencia;
               exit when v_can_movimientos >= v_can_limite;
         end loop;
         -- segundo ciclo para armar detalles
         v_saldo := v_monto1;
         v_can_movimientos := 0;
         v_det_temporal :=  null;
         begin
         for mv in movimientos2(ct.nro_cuenta, v_fec_insercion, v_nro_secuencia) loop
               if mv.cod_tip_movimiento = 'C' then
                  v_saldo := nvl(v_saldo,0) + nvl(mv.monto,0);
               else
                  v_saldo := nvl(v_saldo,0) - nvl(mv.monto,0);
               end if;
               v_det_temporal := v_det_temporal ||
                         lf_for_date(mv.fecha)||
                         lf_for_date(mv.fecha)||
                         lf_for_number(mv.nro_documento,7)||
                         lf_for_char(mv.des_tra_padre,35)||
                         lf_for_char(mv.abr_tra_padre,10)||
                         lf_for_char(mv.cod_tip_movimiento,1)||
                         lf_for_money(mv.monto,16)||
                         lf_for_money(v_saldo,16);
               if (v_can_movimientos / 95) = trunc(v_can_movimientos / 95) then
                   v_det_movimientos := v_det_movimientos ||
                                        v_det_temporal;
                   v_det_temporal := null;
               end if;
               v_can_movimientos := v_can_movimientos + 1;
               --exit when v_can_movimientos >= v_can_limite;
         end loop;
         exception
             when others then
                raise_application_error(-20056,'Error en Mov '||v_can_movimientos);
         end;
         if v_det_temporal is not null then
            v_det_movimientos := v_det_movimientos ||
                                 v_det_temporal;
            v_det_temporal := null;
         end if;
         if v_cod_respuesta = paj_bce.v_cod_aprobado then
            v_che_devuelto := lf_obt_che_devuelto(ct.nro_cuenta);
            -- esta bien el dato se carga el detalle
            v_detalles := v_detalles ||
                          lf_for_money(v_monto1,16)||
                          lf_for_money(v_monto2,16)||
                          lf_for_money(v_monto3,16)||
                          lf_for_char(v_che_devuelto,1);
                       if v_nro_terminal = '999' then
                          v_detalles := v_detalles||
                          lf_for_number(v_can_movimientos,6)||
                          v_det_movimientos;
                       else
                          v_detalles := v_detalles||
                          lf_for_number(v_can_movimientos,3)||
                          v_det_movimientos;                       
                       end if;
         end if;
     end loop;
     if v_can_detalles = 0 then
        -- no tiene detalles
         v_cod_respuesta  := paj_bce.v_cod_cta_inexistente;
     end if;
  end if;
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
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

-- 030-validacion o confirmacion de transferencia entre cuentas
function fu_pro_operacion_030(p_parametros in varchar2)
  return varchar2 is
-- datos recibidos
v_monto           number(18,2) := nvl(to_number(replace(trim(substr(p_parametros,28,16)),',','.')),0);   -- monto a transferir
v_nro_cta_credito varchar2(17) := substr(p_parametros,44,17);   -- cuenta de credito
v_modo            varchar2(1)  := substr(p_parametros,61,1);    -- modo V-validacion o C-confirmacion
-- variables
v_nro_cta_debito  varchar2(17);  -- numero de cuentar
v_cta_for_debito  varchar2(17);  -- cuenta formateada
v_cod_mon_debito  varchar2(3);   -- moneda de la cuenta
v_est_cta_debito  varchar2(1);   -- estado de la cuenta
v_cod_mod_debito  number(4);     -- modulo de la cuenta
v_cod_mad_debito  number(4);     -- modalidad de la cuenta
v_cod_ofi_debito  number(4);     -- oficina de la cuenta
v_nvo_est_debito  varchar2(1) := null; -- cambio de estado de cuenta
v_cot_debito      number(14,8) := null;
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
v_cot_credito      number(14,8) := null;
v_nom_cta_credito  varchar2(100);
v_mto_equ_local    number(18) := null;

v_cod_tra_padre   number(4)  := 388;     -- cod. transaccion padre
v_procesa         varchar2(1) := 'N';    -- indica si se puede o no procesar
v_cotizacion      ge_cotizaciones.val_conversion%type;
begin
  -- 0. inicializo la secuencia
  v_nro_secuencia := 0;
  if (instr(v_nro_cta_credito,'-') > 0 or instr(v_nro_cta_credito,' ') > 0) then
     -- se extrae los guiones de la cuenta
     v_nro_cta_credito := to_number(substr(v_nro_cta_credito,7));
  end if;
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
      -- verifico cuenta de debito
      v_nro_cta_debito := p_dato;
      if v_nro_cta_debito = v_nro_cta_credito then
         v_cod_respuesta := paj_bce.v_cod_tra_invalida;
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
      end if;
     if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
             if v_cod_mon_credito <> v_cod_mon_debito then
                -- moneda diferentes
                -- cod_respuesta := paj_bce.v_cod_tra_invalida;
                Begin
                lp_con_mon_a_moneda(v_cod_mon_debito,
                                    v_cod_mon_credito,
                                    v_monto,
                                    v_mto_credito,
                                    v_cot_debito,
                                    v_cot_credito);
                Exception
                   When OTHERS then
                        v_cod_respuesta := paj_bce.v_cod_otr_error;
                End;
                if v_cod_mon_debito <> v_cod_mon_local then
                   v_cotizacion := v_cot_debito;
                else
                   v_cotizacion := v_cot_credito;
                end if;
             end if;
             if v_mto_credito <= 0 then
                v_cod_respuesta := paj_bce.v_cod_mto_invalido;
             elsif v_cod_mad_credito not in (31,41) then
                v_cod_respuesta := paj_bce.v_cod_cta_invalida;
             elsif v_est_cta_credito not in ('A','I','N','S') then
                v_cod_respuesta := paj_bce.v_cod_cta_invalida;
             elsif pag_cta.fu_ver_tra_prohibida(v_nro_cta_credito,v_cod_tra_padre, 9, 91) = 'S' then
                v_cod_respuesta := paj_bce.v_cod_tra_prohibida;
             elsif v_cod_mad_credito = 31 and pag_cta.fu_obt_cta_cte_comb(v_nro_cta_credito) is not null then
                v_cod_respuesta := paj_bce.v_cod_cta_invalida;
             else
                pag_cta.pr_ver_operacion(v_nro_cta_credito,v_cod_tra_padre,9,91,'C',v_cod_mon_credito, v_mto_credito, v_cod_ofi_origen,
                                         v_cod_mod_credito, v_cod_mad_credito, v_nvo_est_credito, v_sal_dis_credito,
                                         v_procesa,602);
                if v_procesa = 'N' then
                   -- no se puede debitar
                   v_cod_respuesta := paj_bce.v_cod_cta_invalida;
                end if;
             end if;
             -- valido la duplicacion de transferencias
             declare
                 v_existe varchar2(1);
             begin
                 if v_es_mov_noc = 'S' then
                    select distinct 'S'
                      into v_existe
                      from ge_movimientos_noc
                     where nro_cuenta = v_nro_cta_debito
                       and cod_tra_padre = v_cod_tra_padre
                       and monto = v_monto
                       and reversado = 'N'
                       and cod_usuario = v_cod_usuario
                       and instr(concepto,v_nro_cta_credito) > 0
                       --and fecha = v_fec_actual
                       -- Controla que por lo menos haya pasado 10 minutos
                       and ((sysdate) -fec_insercion)*24*60 <=10;
                 else
                    select distinct 'S'
                      into v_existe
                      from ge_movimientos
                     where nro_cuenta = v_nro_cta_debito
                       and cod_tra_padre = v_cod_tra_padre
                       and monto = v_monto
                       and reversado = 'N'
                       and cod_usuario = v_cod_usuario
                       and instr(concepto,v_nro_cta_credito) > 0
                       and fecha = v_fec_actual
                       -- Controla que por lo menos haya pasado 10 minutos
                       and ((sysdate) -fec_insercion)*24*60 <=10;
                       
                 end if;
                 v_cod_respuesta := paj_bce.v_cod_cta_duplicada;   
             exception
                when no_data_found then 
                   null;
                when too_many_rows then
                   v_cod_respuesta := paj_bce.v_cod_cta_duplicada;   
             end;             
        exception
            when no_data_found then
               v_cod_respuesta  := paj_bce.v_cod_cta_inexistente;
            when too_many_rows then
               v_cod_respuesta  := paj_bce.v_cod_cta_duplicada;
            when others then
               v_cod_respuesta  := paj_bce.v_cod_cta_invalida;
        end;
        if v_cod_respuesta = paj_bce.v_cod_aprobado then
           -- no hay problemas hasta aqui
           if v_modo = 'V' then -- validacion
              return lpad(ltrim(lf_for_money(v_cotizacion,16)),16,'0')||
                     lf_for_char(v_cta_for_debito,17)||
                     lf_for_char(v_nom_cta_debito,50)||
                     lf_for_char(rpad(v_cod_mon_debito,3,'.'),3)||
                     lf_for_money(v_monto,16)||
                     lf_for_char(v_cta_for_credito,17)||
                     lf_for_char(v_nom_cta_credito,50)||
                     lf_for_char(rpad(v_cod_mon_credito,3,'.'),3)||
                     lf_for_money(v_mto_credito,16);
           elsif v_modo = 'C' then -- confirmacion
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
                                       v_cod_tra_padre, 503, v_nro_operacion,
                                       v_cotizacion, v_cod_ofi_origen, 9, 91,
                                       null, null, 'Transf. a '||v_nro_cta_credito,
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
                                         v_cod_tra_padre, 602, v_nro_operacion,
                                         v_cot_credito, v_cod_ofi_origen, 9, 91,
                                         null, null, 'Transf. de '||v_nro_cta_debito,
                                         'N', v_nro_secuencia, v_fec_valor,
                                         null, null, v_mto_equ_local);
                if nvl(pag_cta.g_cod_error,0)<> 0 then
                   -- hubo error en el credito
                   v_cod_respuesta := paj_bce.v_cod_tra_invalida;
                end if;
             else
                -- hubo error en el debito
                v_cod_respuesta := paj_bce.v_cod_tra_invalida;
             end if ;
           end if;
        end if;
     end if;
  end if;
  -- no se responde nada, solo se debe setear el v_cod_respuesta
  return null;
end;
-- fin de 030-confirmacion de transferencia entre cuentas

-- 031 - pago de prestamos
function fu_pro_operacion_031(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_modo      varchar2(3) := substr(p_parametros,28,1);   -- modo S/V/C
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
v_det_cuotas      varchar2(3000); -- detalle de las cuotas
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
v_cotizacion      ge_cotizaciones.val_conversion%type;
--
cursor cuotas(p_nro_cuenta in varchar2) is
  select  a.nro_cuota,
          -- nvl(sal_capital,0) + nvl(sal_interes,0) + nvl(sal_int_documentado,0) mto_cuota,
          nvl(c.mto_capital,0) + nvl(c.mto_interes,0) + nvl(c.mto_int_documentado, 0) +
          nvl(c.mto_int_moratorio, 0) + nvl(c.mto_int_mor_interes, 0) + nvl(c.mto_int_mor_adelantado, 0) +
          nvl(c.mto_int_punitorio, 0) + nvl(c.mto_cargo, 0) + nvl(c.mto_impuesto, 0) mto_cuota,
          a.fec_vencimiento, a.fec_ult_pago,
          decode(sign(v_fec_actual - a.fec_vencimiento),1,
                 (v_fec_actual - a.fec_vencimiento), 0 ) dia_mora
    from pr_cobros_tmp c, pr_cuotas a
   where c.nro_cuenta = a.nro_cuenta
     and c.nro_cuota  = a.nro_cuota
     ---
     and a.nro_cuenta = p_nro_cuenta
     and a.nro_cuota > 0
     and a.estado <> 'N'
   order by a.nro_cuota;
begin
  -- 0. Para operaciones de prestamo se graba el usuario con el que se conecta
  v_cod_usuario := user;
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
       where a.nro_cuenta = p_dato
         and a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P';

     exception
        when no_data_found then
           v_cod_respuesta := paj_bce.v_cod_cta_inexistente;
     end;

  end if;
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
           v_cod_respuesta := paj_bce.v_cod_cta_invalida;
        else
            -- sumo los totales
           v_det_cuotas := v_det_cuotas ||
                           lf_for_number(cu.nro_cuota,5)||
                           lf_for_money(cu.mto_cuota,16)||
                           lf_for_date(cu.fec_vencimiento);
        end if;
       end loop;
       -- busco las cuentas de debito
       if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
             v_cod_respuesta := paj_bce.v_cod_pag_pendiente;
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
        v_can_cuo_pagada := substr(p_parametros,29,3);
        v_nro_cta_debito := trim(substr(p_parametros,32,17));
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
        -- valido la duplicacion de pago de pr?stamos
         declare
             v_cant_cob number(5);
         begin
          select count(*)
            into v_cant_cob
            from pr_cobros
           where nro_cuenta = v_nro_cuenta
             and usu_insercion = v_cod_usuario
             and fecha = v_fec_actual;
          If v_cant_cob > 0 Then
             v_cod_respuesta := paj_bce.v_cod_cta_duplicada;   
          end if;
         exception
            when no_data_found then 
               null;
            when too_many_rows then
               v_cod_respuesta := paj_bce.v_cod_cta_duplicada;   
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
           v_cod_respuesta := paj_bce.v_cod_cta_invalida;
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
            if v_cod_moneda <> v_cod_mon_debito and v_cod_respuesta = paj_bce.v_cod_aprobado then
              -- moneda diferentes
              v_cod_respuesta := paj_bce.v_cod_tra_invalida;
            end if;
        end if;
        if v_cod_respuesta <> paj_bce.v_cod_aprobado then
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
                   lf_for_money(v_tot_a_cobrar,16);
        end if;
     elsif v_modo =  'C' then  -- confirmacion
        -- esta la cuenta en condiciones, verifico el horario del deposito
        lp_ver_horario;
        -- verifico la validez de los montos
        begin
          v_can_cuo_pagada := substr(p_parametros,29,3);
          v_nro_cta_debito := trim(substr(p_parametros,32,17));
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

          v_nro_sobre      := trim(substr(p_parametros,49,10));
          v_imp_efectivo   := nvl(to_number(replace(trim(substr(p_parametros,59,18)),',','.')),0);   -- efectivo
          v_imp_che_n_bco  := nvl(to_number(replace(trim(substr(p_parametros,77,18)),',','.')),0);  -- che.ntro.bco
          v_imp_che_o_bco  := nvl(to_number(replace(trim(substr(p_parametros,95,18)),',','.')),0);  -- che otros bcos.
          v_imp_debito     := nvl(to_number(replace(trim(substr(p_parametros,113,18)),',','.')),0);   -- total
          v_tot_pago       := nvl(to_number(replace(trim(substr(p_parametros,131,18)),',','.')),0);   -- total
          if v_cod_moneda = v_cod_mon_local then
             if v_imp_efectivo <> trunc(v_imp_efectivo) or
                v_imp_che_n_bco <> trunc(v_imp_che_n_bco) or
                v_imp_che_o_bco <> trunc(v_imp_che_o_bco)  or
                v_imp_debito <> trunc(v_imp_debito) then
               -- monto con decimales y en guaranies no permite
               v_cod_respuesta := paj_bce.v_cod_mto_invalido;
             elsif nvl(v_imp_efectivo,0) + nvl(v_imp_che_n_bco,0) +
                   nvl(v_imp_che_o_bco,0) + nvl(v_imp_debito,0) <> nvl(v_tot_pago,0) then
                   -- total depositado invalido
                   v_cod_respuesta := paj_bce.v_cod_tot_invalido;
             end if;
          end if;
        exception
          when others then
             -- monto invalido
             v_cod_respuesta := paj_bce.v_cod_mto_invalido;
        end;
        if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
              v_cod_transaccion := 615;
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
                                 'O', -- cheque otros bcos
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
             -- valido la duplicacion de pago de pr?stamos
             declare
                 v_existe varchar2(1);
             begin
                 if v_es_mov_noc = 'S' then
                    select 'S'
                      into v_existe
                      from ge_movimientos_noc
                     where nro_cuenta = v_nro_cta_debito
                       and cod_tra_padre = v_cod_tra_padre
                       and monto = v_imp_debito
                       and reversado = 'N'
                       and cod_usuario = v_cod_usuario
                       and concepto = 'Pago de Prestamos'
                       and rownum = 1;
                 else
                    select 'S'
                      into v_existe
                      from ge_movimientos
                     where nro_cuenta = v_nro_cta_debito
                       and cod_tra_padre = v_cod_tra_padre
                       and monto = v_imp_debito
                       and reversado = 'N'
                       and cod_usuario = v_cod_usuario
                       and concepto = 'Pago de Prestamos'
                       and rownum = 1;             
                 end if;
                 v_cod_respuesta := paj_bce.v_cod_cta_duplicada;   
             exception
                when no_data_found then 
                   null;
                when too_many_rows then
                   v_cod_respuesta := paj_bce.v_cod_cta_duplicada;   
             end;

             -- genero el movimiento respectivo
              begin
                select cod_moneda
                  into v_cod_mon_debito
                  from ge_cuentas
                 where nro_cuenta = v_nro_cta_debito;
                if v_cod_mon_debito <> v_cod_moneda then
                   v_cod_respuesta := paj_bce.v_cod_tra_invalida;
                end if;
              exception
                 when others then
                    v_cod_respuesta := paj_bce.v_cod_cta_inexistente;
              end;
              if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
                    v_cod_respuesta := paj_bce.v_cod_tra_invalida;
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
function fu_pro_operacion_032(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_modo      varchar2(3) := substr(p_parametros,28,1);   -- modo S/V/C
-- datos a responder
v_detalles        clob := null;   -- datos de las cuentas
-- variables
v_nro_cuenta      varchar2(17);
v_nro_tarjeta     varchar2(16);
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
v_cotizacion      ge_cotizaciones.val_conversion%type;

begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     begin
       select a.nro_cuenta,
              c.nro_tarjeta,
              c.nom_embozar,
              d.descripcion,
              a.cod_moneda,
              a.sal_pag_minimo,
              a.sal_ult_extracto,
              (nvl(a.sal_facturar,0)+
               nvl(a.sal_facturado,0)+
               nvl(a.sal_financiado,0)+
               nvl(a.sal_cuo_pendientes,0)),
              a.fec_ult_cierre,
              a.cod_modulo,
              a.cod_modalidad,
              a.cod_oficina
        into v_nro_cuenta,
             v_nro_tarjeta,
             v_embozado,
             v_tip_tarjeta,
             v_cod_moneda,
             v_mto_pag_minimo,
             v_deu_ult_cierre,
             v_deu_actual,
             v_fec_ult_cierre,
             v_cod_mod_cta,
             v_cod_mad_cta,
             v_cod_ofi_cta
        from ge_modalidades d, ta_tarjetas c, ge_cta_clientes b, ta_cta_tarjetas a
       where a.nro_cuenta = p_dato
         and a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and c.nro_cuenta = b.nro_cuenta
         and c.cod_persona = b.cod_persona
         and c.vigente = 'S'
         and d.cod_modulo = a.cod_modulo
         and d.cod_modalidad = a.cod_modalidad;
     exception
        when no_data_found then
           v_cod_respuesta := paj_bce.v_cod_cta_inexistente;
     end;

  end if;
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     if v_modo = 'S' then -- seleccion de datos
       -- busco las cuentas de debito
       if v_cod_respuesta = paj_bce.v_cod_aprobado then
          v_detalles := fu_pro_operacion_011(p_parametros, 'D',v_cod_moneda,'032');
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
     elsif v_modo in ('V','C') then  -- validacion o confirmacion
        -- esta la cuenta en condiciones, verifico el horario del deposito
        lp_ver_horario;
        -- verifico la validez de los montos
        begin
          v_nro_cta_debito := trim(substr(p_parametros,29,17));
          if v_nro_cta_debito is not null then
            if (instr(v_nro_cta_debito,'-') > 0 or instr(v_nro_cta_debito,' ') > 0) then
               -- se extrae los guiones de la cuenta
                v_nro_cta_debito := to_number(substr(v_nro_cta_debito,7));
            end if;
          end if;
          v_nro_sobre      := trim(substr(p_parametros,46,10));
          v_imp_efectivo   := nvl(to_number(replace(trim(substr(p_parametros,56,18)),',','.')),0);   -- efectivo
          v_imp_che_n_bco  := nvl(to_number(replace(trim(substr(p_parametros,74,18)),',','.')),0);  -- che.ntro.bco
          v_imp_che_o_bco  := nvl(to_number(replace(trim(substr(p_parametros,92,18)),',','.')),0);  -- che otros bcos.
          v_imp_debito     := nvl(to_number(replace(trim(substr(p_parametros,110,18)),',','.')),0);   -- total
          v_tot_pago       := nvl(to_number(replace(trim(substr(p_parametros,128,18)),',','.')),0);   -- total
          if v_cod_moneda = v_cod_mon_local then
             if v_imp_efectivo <> trunc(v_imp_efectivo) or
                v_imp_che_n_bco <> trunc(v_imp_che_n_bco) or
                v_imp_che_o_bco <> trunc(v_imp_che_o_bco)  or
                v_imp_debito <> trunc(v_imp_debito) then
               -- monto con decimales y en guaranies no permite
               v_cod_respuesta := paj_bce.v_cod_mto_invalido;
             elsif nvl(v_imp_efectivo,0) + nvl(v_imp_che_n_bco,0) +
                   nvl(v_imp_che_o_bco,0) + nvl(v_imp_debito,0) <> nvl(v_tot_pago,0) then
                   -- total depositado invalido
                   v_cod_respuesta := paj_bce.v_cod_tot_invalido;
             end if;
          end if;
        exception
          when others then
             -- monto invalido
             v_cod_respuesta := paj_bce.v_cod_mto_invalido;
        end;
        if v_cod_respuesta = paj_bce.v_cod_aprobado then
           if v_modo = 'V' then -- solo se valida
              -- 
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
                v_cod_respuesta := paj_bce.v_cod_tra_invalida;
             end if;
             If v_cod_respuesta = paj_bce.v_cod_aprobado then
               declare
                   v_existe varchar2(1);
               begin
                  if v_es_mov_noc = 'S' then
                      select 'S'
                        into v_existe
                        from ge_movimientos_noc
                       where nro_cuenta = v_nro_cta_debito
                         and cod_tra_padre = v_cod_tra_padre
                         and monto = v_imp_debito
                         and reversado = 'N'
                         and cod_usuario = v_cod_usuario
                         and rownum = 1;
                   else
                      select 'S'
                        into v_existe
                        from ge_movimientos
                       where nro_cuenta = v_nro_cta_debito
                         and cod_tra_padre = v_cod_tra_padre
                         and monto = v_imp_debito
                         and reversado = 'N'
                         and cod_usuario = v_cod_usuario
                         and rownum = 1;             
                   end if;
                   v_cod_respuesta := paj_bce.v_cod_cta_duplicada;   
               exception
                  when no_data_found then 
                     null;
                  when too_many_rows then
                     v_cod_respuesta := paj_bce.v_cod_cta_duplicada;   
               End;
             End if;
             return  lpad(ltrim(lf_for_money(v_cotizacion,16)),16,'0')||
                     lf_for_char(v_cta_for_debito,17)||
                     lf_for_char(v_nom_cta_debito,50)||
                     lf_for_char(rpad(v_cod_mon_debito,3,'.'),3)||
                     lf_for_money(v_imp_debito,16)||
                     lf_for_char(v_nro_tarjeta,17)||
                     lf_for_char(v_embozado,50)||
                     lf_for_char(rpad(v_cod_moneda,3,'.'),3)||
                     lf_for_money(v_imp_debito,16);
          end if;
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
              v_cod_transaccion := 615;
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
                                 'O', -- cheque otros bcos
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
             -- verifico sino hay pagos con el mismo monto 
             declare
                 v_existe varchar2(1);
             begin
                 if v_es_mov_noc = 'S' then
                    select 'S'
                      into v_existe
                      from ge_movimientos_noc
                     where nro_cuenta = v_nro_cta_debito
                       and cod_tra_padre = v_cod_tra_padre
                       and monto = v_imp_debito
                       and reversado = 'N'
                       and cod_usuario = v_cod_usuario
                       and rownum = 1;
                 else
                    select 'S'
                      into v_existe
                      from ge_movimientos
                     where nro_cuenta = v_nro_cta_debito
                       and cod_tra_padre = v_cod_tra_padre
                       and monto = v_imp_debito
                       and reversado = 'N'
                       and cod_usuario = v_cod_usuario
                       and rownum = 1;             
                 end if;
                 v_cod_respuesta := paj_bce.v_cod_cta_duplicada;   
             exception
                when no_data_found then 
                   null;
                when too_many_rows then
                   v_cod_respuesta := paj_bce.v_cod_cta_duplicada;   
             end;
             if v_cod_respuesta = paj_bce.v_cod_aprobado then
                 -- genero el movimiento respectivo
                 lp_ins_movimiento( v_cod_mod_cta,
                                    v_cod_mad_cta,
                                    v_cod_ofi_cta,
                                    v_nro_cuenta,
                                    v_cod_moneda,
                                    v_cod_tra_padre,
                                    978,
                                    v_nro_sobre,
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
                       v_cod_respuesta := paj_bce.v_cod_tra_invalida;
                    end if;
                  exception
                     when others then
                        v_cod_respuesta := paj_bce.v_cod_cta_inexistente;
                  end;
              end if;
              if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
                   -- v_cod_respuesta := paj_bce.v_cod_tra_invalida;
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

-- 033-validacion o confirmacion de Pago a Proveedores
function fu_pro_operacion_033(p_parametros in varchar2)
  return varchar2 is

-- Datos Recibidos del HB
v_monto           number(18,2) := nvl(to_number(replace(trim(substr(p_parametros,28,16)),',','.')),0);   -- monto a transferir
v_modo            varchar2(1)  := substr(p_parametros,44,1);    -- modo V-validacion o C-confirmacion
v_campo1          varchar2(15) := substr(p_parametros,45,15);   -- Ruc Importador
v_campo2          varchar2(15) := substr(p_parametros,60,15);   -- Ruc Despachante

-- Variables
v_nro_cta_debito  varchar2(17);      -- Numero de Cuenta Debito
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
v_cod_tra_padre   number(4);         -- Cod. transaccion padre
v_cod_servicio    number(3) := 6;    -- Cod del Servicicio (6=Despacho Aduaneros)
v_for_campo1      varchar2(20);      -- Formato campo1
v_for_campo2      varchar2(20);      -- Formato campo1
v_res_DNA         varchar2(500);     -- Respuesta de la DNA
v_pos1            number(3);
v_pos2            number(3);
v_nom_importador  varchar(30);
v_nom_despachante varchar(30);

begin
  -- 0. inicializo la secuencia
  v_nro_secuencia := 0;
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas

  if v_cod_respuesta = paj_bce.v_cod_aprobado then
      -- Busco el cobro de servicio
      begin
        select nro_cuenta, cod_transaccion,
               for_campo1, for_campo1
         into v_nro_cta_credito, v_cod_tra_padre,
              v_for_campo1, v_for_campo2
         from ge_cob_ser_parametros f
        where cod_servicio = v_cod_servicio;
      exception
          when others then
             v_cod_respuesta  := paj_bce.v_cod_ser_inexistente;
      end;

      -- Validacion de los Campos de Ruc (Importador/Despachante)
      v_campo1 := trim(v_campo1);
      v_campo2 := trim(v_campo2);
      if length(nvl(v_campo1,'X')) < length(nvl(v_for_campo1,'XX')) then
         v_cod_respuesta := paj_bce.v_cod_dat_invalido;
      elsif length(nvl(v_campo2,'X')) < length(nvl(v_for_campo2,'XX')) then
         v_cod_respuesta := paj_bce.v_cod_dat_invalido;
      end if;

      -- verifico la cuenta para debito
      v_nro_cta_debito := p_dato; -- El Nro de Cuenta que validada para ingresar
      -- La cuenta de debito no puede ser igual a la de credito
      if v_nro_cta_debito = v_nro_cta_credito then
         v_cod_respuesta := paj_bce.v_cod_tra_invalida;
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
      end if;
      
      -- Si la cuenta de Debito esta Ok continuo
      if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
               v_cod_respuesta  := paj_bce.v_cod_cta_inexistente;
            when too_many_rows then
               v_cod_respuesta  := paj_bce.v_cod_cta_duplicada;
            when others then
               v_cod_respuesta  := paj_bce.v_cod_cta_invalida;
        end;

        if v_cod_mon_credito <> v_cod_mon_debito then
           -- La cta de Debito debe ser la misma moneda que la cta de la DNA
           v_cod_respuesta := paj_bce.v_cod_mto_invalido;
        else
           v_mto_credito := v_monto;
        end if;
       
        if v_cod_respuesta = paj_bce.v_cod_aprobado then
          -- Validaciones de la Cuenta de Credito
          if v_mto_credito <= 0 then
             v_cod_respuesta := paj_bce.v_cod_mto_invalido;
          elsif v_cod_mad_credito not in (31,41) then
             v_cod_respuesta := paj_bce.v_cod_cta_invalida;
          elsif v_est_cta_credito not in ('A','I','N','S') then
             v_cod_respuesta := paj_bce.v_cod_cta_invalida;
          elsif pag_cta.fu_ver_tra_prohibida(v_nro_cta_credito,v_cod_tra_padre, 9, 91) = 'S' then
             v_cod_respuesta := paj_bce.v_cod_tra_prohibida;
          elsif v_cod_mad_credito = 31 and pag_cta.fu_obt_cta_cte_comb(v_nro_cta_credito) is not null then
             v_cod_respuesta := paj_bce.v_cod_cta_invalida;
          else
             pag_cta.pr_ver_operacion(v_nro_cta_credito,v_cod_tra_padre,9,91,'C',v_cod_mon_credito, v_mto_credito, v_cod_ofi_origen,
                                      v_cod_mod_credito, v_cod_mad_credito, v_nvo_est_credito, v_sal_dis_credito,
                                      v_procesa,602);
             if v_procesa = 'N' then
                -- no se puede debitar
                v_cod_respuesta := paj_bce.v_cod_cta_invalida;
             end if;
          end if;
             
          --*******************************************
          -- valido la duplicacion de transferencias
          declare
              v_existe varchar2(1);
          begin
            if v_es_mov_noc = 'S' then
               select distinct 'S'
                 into v_existe
                 from ge_movimientos_noc
                where nro_cuenta = v_nro_cta_debito
                  and cod_tra_padre = v_cod_tra_padre
                  and monto = v_monto
                  and reversado = 'N'
                  and cod_usuario = v_cod_usuario
                  and concepto like ('%'||v_campo1||'%') 
                  and concepto like ('%'||v_campo2||'%')
                  -- Controla que por lo menos haya pasado 10 minutos
                  and ((sysdate) -fec_insercion)*24*60 <=10;
            else
               select distinct 'S'
                 into v_existe
                 from ge_movimientos
                where nro_cuenta = v_nro_cta_debito
                  and cod_tra_padre = v_cod_tra_padre
                  and monto = v_monto
                  and reversado = 'N'
                  and cod_usuario = v_cod_usuario
                  and concepto like ('%'||v_campo1||'%') 
                  and concepto like ('%'||v_campo2||'%')
                  and fecha = v_fec_actual
                   -- Controla que por lo menos haya pasado 10 minutos
                  and ((sysdate) -fec_insercion)*24*60 <=10;
            end if;
               v_cod_respuesta := paj_bce.v_cod_cta_duplicada;   
           exception
              when no_data_found then 
                 null;
              when too_many_rows then
                 v_cod_respuesta := paj_bce.v_cod_cta_duplicada;   
           end;             
        --****************************
        end if;
        
        if v_cod_respuesta = paj_bce.v_cod_aprobado then
           -- no hay problemas hasta aqui
           if v_modo = 'V' then -- validacion
              v_res_DNA := fug_val_dna('ValidarRuc',
                           ltrim(nvl(v_nro_terminal,999),'000'),
                           To_number(v_nro_operacion),
                           'TDA', -- fijo
                           trim(v_campo1), -- Ruc Importador
                           trim(v_campo2), -- Ruc Despachante
                           v_monto,
                           user);
              if v_res_DNA not like '00-%' then
                 -- hay error
                 v_cod_respuesta := paj_bce.v_cod_rec_por_DNA;
                 v_pos1 := instr(v_res_DNA,'#');
                 if v_pos1 is not null then
                        return substr(v_res_DNA,4,v_pos1-4);
                 else
                        return substr(v_res_DNA,4,100);
                 end if;
              else
                 v_pos1 := instr(v_res_DNA,'#');
                 v_pos2 := instr(v_res_DNA,'#',v_pos1+1);
                 if v_pos1 > 0 and v_pos2 > 0 then
                     v_nom_importador := substr(v_res_DNA,v_pos1+1,v_pos2-v_pos1-1);
                     v_nom_despachante := substr(v_res_DNA,v_pos2+1);
                 return lpad(ltrim(lf_for_money(v_cotizacion,16)),16,'0')||
                     lf_for_char(v_cta_for_debito,17)||
                     lf_for_char(v_nom_cta_debito,50)||
                     lf_for_char(rpad(v_cod_mon_debito,3,'.'),3)||
                     lf_for_money(v_monto,16)||
                     lf_for_char(v_campo1,15)||
                     lf_for_char(v_nom_importador,30)||
                     lf_for_char(v_campo2,15)||
                     lf_for_char(v_nom_despachante,30);
                 end if; 
              end if;
           elsif v_modo = 'C' then -- confirmacion
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
                                       v_cod_tra_padre, 503, v_nro_operacion,
                                       v_cotizacion, v_cod_ofi_origen, 9, 91,
                                       null, null, 'Imp: '||v_campo1||' '||'Desp: '||v_campo2,
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
                                          v_cod_tra_padre, 602, v_nro_operacion,
                                          v_cot_credito, v_cod_ofi_origen, 9, 91,
                                          null, null, 'Imp: '||v_campo1||' '||'Desp: '||v_campo2,
                                          'N', v_nro_secuencia, v_fec_valor,
                                          null, null, v_mto_equ_local);
                 if nvl(pag_cta.g_cod_error,0)<> 0 then
                   -- hubo algun error en el credito
                   v_cod_respuesta := paj_bce.v_cod_tra_invalida;
                 else
                   -- Si el Credito y el Debito fueron relizado envio a la Aduana
                   if v_cod_respuesta = paj_bce.v_cod_aprobado then
                      v_res_DNA := fug_val_dna('CrearDeposito',
                                   ltrim(nvl(v_nro_terminal,999),'000'),
                                   To_number(v_nro_operacion),
                                   'TDA', -- fijo
                                   trim(v_campo1), -- Ruc Importador
                                   trim(v_campo2), -- Ruc Despachante
                                   v_monto,
                                   user);
                      if v_res_DNA not like '00-%' then
                         -- hay error
                         v_cod_respuesta := paj_bce.v_cod_rec_por_DNA;
                         v_pos1 := instr(v_res_DNA,'#');
                         if v_pos1 is not null then
                                return substr(v_res_DNA,4,v_pos1-4);
                         else
                                return substr(v_res_DNA,4,100);
                         end if;
                      end if;
                   end if;
                 end if;
              else
                 -- hubo algun error en el debito
                 v_cod_respuesta := paj_bce.v_cod_tra_invalida;
              end if;
           else
              -- No es del tipo V Validacion ni C Confirmacion
              v_cod_respuesta := paj_bce.v_cod_tra_invalida;
           end if;
        end if;
     end if;
  end if;
  -- no se responde nada, solo se debe setear el v_cod_respuesta
  return null;
end;
-- fin de 033-Pago a Proveedores

-- 040  Consulta de cheques devueltos
function fu_pro_operacion_040(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_ver_todas      varchar2(1) := substr(p_parametros,28,1);   -- ver todas las cuentas s/n
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
     and b.cod_persona = v_cod_persona
     and a.cod_modulo = c.cod_modulo
     and a.cod_modalidad = c.cod_modalidad
     and a.estado = c.estado
     and c.activo = 'S'  -- solo cuentas activas
     and a.estado <> 'X' -- pendiente de verificacion
     and b.cod_modalidad in (31,41)
     and (v_ver_todas = 'S' or b.nro_cuenta = p_dato); -- solo ve la cuenta recibida o todas
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
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     v_can_detalles := 0;
     for ct in cuentas loop
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
         if v_cod_respuesta = paj_bce.v_cod_aprobado then
            -- esta bien el dato se carga el detalle
            v_detalles := v_detalles ||
                          lf_for_number(v_can_movimientos,3)||
                          v_det_movimientos;
         end if;
     end loop;
     if v_can_detalles = 0 then
        -- no tiene detalles
         v_cod_respuesta  := paj_bce.v_cod_cta_inexistente;
     end if;
  end if;
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
v_ver_todas      varchar2(1) := substr(p_parametros,28,1);   -- ver todas las cuentas s/n
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
     and b.cod_persona = v_cod_persona
     and a.cod_modulo = c.cod_modulo
     and a.cod_modalidad = c.cod_modalidad
     and a.estado = c.estado
     and c.activo = 'S'  -- solo cuentas activas
     and a.estado <> 'X' -- pendiente de verificacion
     and b.cod_modalidad in (31,41)
     and (v_ver_todas = 'S' or b.nro_cuenta = p_dato); -- solo ve la cuenta recibida o todas
-- movimientos de depositos a cofirmar por cuenta
cursor movimientos(p_nro_cuenta in varchar2) is
  select nro_documento, monto, fec_inicio, fec_final
    from ah_retenciones
   where nro_cuenta = p_nro_cuenta
     and liberado = 'N'
   order by fec_inicio, fec_final;

begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     v_can_detalles := 0;
     for ct in cuentas loop
         v_can_detalles := v_can_detalles + 1;
         v_detalles :=  v_detalles ||
                        lf_for_char(ct.cta_formateada,17)||
                        lf_for_char(ct.cod_tip_cuenta,2)||
                        lf_for_char(ct.des_tip_cuenta,35)||
                        lf_for_char(ct.nom_cuenta,50)||
                        lf_for_char(rpad(ct.cod_moneda,3,'.'),3);
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
         if v_cod_respuesta = paj_bce.v_cod_aprobado then
            v_che_devuelto := lf_obt_che_devuelto(ct.nro_cuenta);
            -- esta bien el dato se carga el detalle
            v_detalles := v_detalles ||
                          lf_for_char(v_che_devuelto,1)||
                          lf_for_number(v_can_movimientos,3)||
                          v_det_movimientos;
         end if;
     end loop;
     if v_can_detalles = 0 then
        -- no tiene detalles
         v_cod_respuesta  := paj_bce.v_cod_cta_inexistente;
     end if;
  end if;
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
         val_compra, val_venta, val_com_cheque, val_ven_cheque
    from ba_monedas c,ge_cotizaciones a
   where a.cod_moneda in ('USD','EUR','RS','ARP')
     and a.cod_moneda = c.cod_moneda
     and fecha = (select max(fecha)
                    from ge_cotizaciones b
                   where b.cod_moneda = a.cod_moneda)
    order by decode(a.cod_moneda,'USD',1,'EUR',2,'RS',3,'ARP',4);

begin
   for ct in cotizaciones loop
       v_can_detalles := v_can_detalles + 1;
       v_detalles :=  v_detalles ||
                      lf_for_char(ct.des_moneda,30)||
                      lf_for_money(ct.val_compra,16)||
                      lf_for_money(ct.val_venta,16)||
                      lf_for_money(ct.val_com_cheque,16)||
                      lf_for_money(ct.val_ven_cheque,16);
   end loop;
   if v_can_detalles = 0 then
      -- no tiene cuentas
       v_cod_respuesta  := paj_bce.v_cod_cta_inexistente;
   end if;
   if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
function fu_pro_operacion_060(p_parametros in varchar2)
  return clob is
-- datos recibidos
v_modo      varchar2(1)   := substr(p_parametros,28,1);   -- ver todas las cuentas s/n
--
v_sol_tip_che varchar(5);
v_sol_can_che number(4);
v_sol_ofi_ret number(3);
-- datos a responder
v_can_agencias    number(3);     -- cantidad de agencias
v_can_tip_che     number(3);     -- cantidad de tipos de chequeras
--
v_det_agencias    varchar2(1000); -- datos de las cuentas
v_det_tip_che     varchar2(1000); -- datos de los tipos de chequeras
v_can_chequera    varchar2(100);  -- cantidad de chequeras
v_cantidad        varchar2(5);
v_pos             number(5);
v_cod_moneda      varchar2(4);
v_des_cuenta      varchar2(100);
v_existe          varchar2(1) := 'N';
-- cursor de agencias
cursor agencias is
  select cod_oficina, descripcion
    from ba_oficinas
   where estado = 'A';
-- tipos de chequeras
cursor tip_cheq is
  select cod_tip_chequera, descripcion, can_cheques, tipo, can_maxima, cod_moneda,
         cod_transaccion
    from cc_tip_chequeras
   where (cod_moneda is null or cod_moneda = v_cod_moneda);

begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     begin
        select cod_moneda, denominacion
          into v_cod_moneda, v_des_cuenta
          from cc_cta_corrientes
         where nro_cuenta = p_dato
           and estado = 'N';
     exception
         when others then
           v_cod_respuesta := paj_bce.v_cod_can_invalida;
     end;
     if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
              if pag_cta.fu_ver_tra_prohibida(p_dato,tc.cod_transaccion,4, 41) = 'N' then
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
               v_cod_respuesta  := paj_bce.v_cod_tra_prohibida;
           end if;
           -- fin de la seleccion
           if v_cod_respuesta = paj_bce.v_cod_aprobado then
               -- todo ok, se arma el mensaje de respuesta
               return lf_for_number(v_can_tip_che,3)||
                      lf_for_number(v_can_agencias,3)||
                      lf_for_char(v_des_cuenta,50)||
                      v_det_tip_che||
                      v_det_agencias||v_det_agencias;
           else
               return null;  -- nada
           end if;
       elsif v_modo = 'C' then -- confirmacion de datos
           v_sol_tip_che := substr(p_parametros,29,5);
           v_sol_can_che := substr(p_parametros,34,3);
           v_sol_ofi_ret := substr(p_parametros,37,3);
           declare
              v_cod_transaccion number(4);
           begin
               -- busco la transaccion que corresponde para verificar prohibiciones
               select cod_transaccion
                 into v_cod_transaccion
                 from cc_tip_chequeras
                where cod_tip_chequera = substr(v_sol_tip_che,1,1)
                  and (cod_moneda is null or cod_moneda = v_cod_moneda);
               if pag_cta.fu_ver_tra_prohibida(p_dato,v_cod_transaccion,4, 41) = 'N' then
                   Begin
                     -- Antes de insertar verifico si es que no existe un pedido similar.
                      select 'S' into v_existe
                        from cc_sol_chequeras
                       where nro_cuenta = p_dato
                         and cod_tip_chequera = substr(v_sol_tip_che,1,1)
                         and cantidad = v_sol_can_che
                         and can_hojas = substr(v_sol_tip_che,3,3)
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
                       v_cod_respuesta := paj_bce.v_cod_ped_duplicado;
                    end if;
                   --inserto el registro de la solicitud de chequeras
                   if v_cod_respuesta = paj_bce.v_cod_aprobado then
                     insert into cc_sol_chequeras
                       (nro_cuenta, fecha, hora, cod_usuario, cod_tip_chequera,
                        cantidad, can_hojas, estado, cod_ofi_retiro)
                     values
                       (p_dato,v_fec_actual, v_hor_actual, v_cod_usuario,
                        substr(v_sol_tip_che,1,1), v_sol_can_che,
                        substr(v_sol_tip_che,3,3), 'S', v_sol_ofi_ret);
                   End if;
               else
                  v_cod_respuesta := paj_bce.v_cod_tra_prohibida;
               end if;
           exception
              when others then
                  v_cod_respuesta := paj_bce.v_cod_tra_prohibida;
           end;
           return null;
       end if;
     end if;
  end if;
  return null;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 060 - Solicitud de chequeras

-- 061 Consulta de Chequeras
function fu_pro_operacion_061(p_parametros in varchar2)
  return clob is
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
     and nro_cuenta = p_dato
     Order by fec_solicitud desc;
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     begin
        select fug_cta_formateada(cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, cod_moneda),
               cod_moneda, denominacion, fug_obt_des_modal(cod_modulo, cod_modalidad)
          into v_cta_formateada, v_cod_moneda, v_des_cuenta, v_tip_cuenta
          from cc_cta_corrientes
         where nro_cuenta = p_dato
           and estado = 'N';
     exception
         when others then
           v_cod_respuesta := paj_bce.v_cod_can_invalida;
     end;
     Begin
       Select nvl(count(*), 0)
         into v_can_detalles
         from cc_chequeras
        where nro_cuenta = p_dato;
       If v_can_detalles > 40 then
          -- Se establece 40 como maximo.
          v_can_detalles := 40;
       End if;
     End;
     ---
     if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
v_nro_cheque      cc_chequeras.nro_che_inicial%type := substr(p_parametros, 28, 7);
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
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
           and cc_chequeras.nro_cuenta = p_dato
           and cc_chequeras.nro_che_inicial <= v_nro_cheque
           and cc_chequeras.nro_che_final >= v_nro_cheque;
        v_importe := null;
     Exception
        When NO_DATA_FOUND then
             v_cod_respuesta := paj_bce.v_cod_cta_inexistente;
     End;
     ---
     if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
                and nro_cuenta = p_dato;
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
              where cc_cta_corrientes.nro_cuenta = p_dato
                and cc_cta_corrientes.nro_cuenta = cc_che_ord_no_pagos.nro_cuenta
                and ge_causales.cod_causa(+) = cc_che_ord_no_pagos.cod_causa
                and ge_causales.tipo(+) = 'O'
                and nro_cheque = v_nro_cheque
                and cc_che_ord_no_pagos.nro_cuenta = p_dato;
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
              where cc_cta_corrientes.nro_cuenta = p_dato
                and cc_cta_corrientes.nro_cuenta = cc_che_certificados.nro_cuenta
                and ge_causales.cod_causa(+) = cc_che_certificados.cod_cau_devolucion
                and ge_causales.tipo(+) = 'D'
                and nro_cheque = v_nro_cheque
                and cc_che_certificados.nro_cuenta = p_dato;
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
              where cc_cta_corrientes.nro_cuenta = p_dato
                and cc_cta_corrientes.nro_cuenta = cc_che_ger_emitidos.nro_cuenta
                and nro_cheque = v_nro_cheque
                and cc_che_ger_emitidos.nro_cuenta = p_dato;
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
              where cc_cta_corrientes.nro_cuenta = p_dato
                and cc_cta_corrientes.nro_cuenta = cc_che_anulados.nro_cuenta
                and ge_causales.cod_causa(+) = cc_che_anulados.cod_causa
                and ge_causales.tipo(+) = 'A'
                and nro_cheque = v_nro_cheque
                and cc_che_anulados.nro_cuenta = p_dato;
             v_posee_det := 'S';
           Exception
              When NO_DATA_FOUND then
                   v_posee_det := 'N';
           End;
        End if;
     end if;
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
v_nro_inicial     cc_chequeras.nro_che_inicial%type := substr(p_parametros, 28, 7);
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
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
           and nro_cuenta = p_dato
           and nro_che_inicial = v_nro_inicial;
     End;
     ---
     if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
        v_cod_respuesta := paj_bce.v_cod_cta_sin_mov;
     End if;
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
v_nro_inicial     cc_chequeras.nro_che_inicial%type := substr(p_parametros, 28, 7);
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
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
           and nro_cuenta = p_dato
           and nro_che_inicial = v_nro_inicial;
     End;
     ---
     if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
        v_cod_respuesta := paj_bce.v_cod_cta_sin_mov;
     End if;
     return v_detalles;
  end if;
  return null;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end;
-- fin de la 064 - Consulta de Chequeras - Detalle de una chequera

-- control y actualizacion de pago de sueldos
function fu_pro_operacion_070(p_parametros in varchar2)
  return clob is
-- datos recibidos
p_modo           varchar2(1)  := substr(p_parametros,28,1);             -- modo de control
p_cod_ente       number(5)    := substr(p_parametros,29,5);
p_cod_moneda     varchar2(3)  := trim(substr(p_parametros,29+5,3));             -- moneda
p_tot_debito     number(18,2) := to_number(substr(p_parametros,32+5,16)); -- monto total sueldos
p_tip_remuneracion varchar2(1)  := substr(p_parametros,48+5,1);   -- Tipo de remuneracion 
p_can_cuentas    number(3)    := to_number(substr(p_parametros,48+6,3));  -- cantidad de cuentas
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
v_can_detalles   number(3)    := 0; -- cantidad de cuentas
--
v_detalles       clob := null; -- datos de las cuentas
--
v_cod_ente       number(6);         -- codigo del ente
v_des_ente       varchar2(100);     -- descripcion del ente
v_nro_cta_debito varchar2(17);      -- cuenta de debito
v_res_principal  varchar2(03) := '000'; -- respuesta
v_lugar          varchar2(2000);
begin
   -- 1. valido la clave del cliente
   pr_val_clave(p_parametros);
   -- 2. Verifico si la persona tiene el servicio de pago de sueldos
   if v_cod_respuesta = paj_bce.v_cod_aprobado then
     begin
        select a.cod_ente, a.descripcion,
               fug_obt_parentes(a.cod_ente,'NRO_CTA_DEBITO')
          into v_cod_ente, v_des_ente, v_nro_cta_debito
          from ge_entes a
         where a.cod_persona = v_cod_persona
           and a.tipo = 'SU'
           and a.cod_ente = p_cod_ente
           and fug_obt_parentes(a.cod_ente,'SER_ACTIVO') = 'S'
           and fug_obt_parentes(a.cod_ente,'HAB_HOMEBANKING') = 'S';
     exception
        when too_many_rows then
           v_cod_respuesta := paj_bce.v_cod_cta_duplicada;
        when others then
            v_cod_respuesta := paj_bce.v_cod_sin_autorizacion;
     end;
   end if;
   -- 3. Tomo la cantidad de cuentas recibidas
   if v_cod_respuesta = paj_bce.v_cod_aprobado then
     If p_modo = 'C' then -- Es confirmacion y no hubo errores...
        -- Al confirmar debe insertar en ge_pag_sueldos_tmp.
        pag_sue.LP_DEL_DATOS_TEMPORA(v_cod_ente, v_fec_actual, v_lugar);
        -- Se le agreg? este control.
        delete from ge_pag_sueldos_tmp
        where cod_ente = v_cod_ente
          and fec_envio = v_fec_actual
          and fec_proceso is null;
     End if;
     ---
     for i in 1..p_can_cuentas
     loop
         v_nro_cuenta     := trim(substr(p_parametros, 57 + ((i-1)*33), 17));
         --v_monto          := nvl(to_number(substr(p_parametros,68 + ((i-1)*33), 16),0),0);
         v_monto          := substr(p_parametros,74 + ((i-1)*33), 16);

         v_tot_detalles   := v_tot_detalles + v_monto;
         v_can_detalles   := v_can_detalles + 1;
         -- valido la cuenta recibida
         begin
            v_cta_formateada := null;
            v_cod_tip_cuenta := null;
            v_des_tip_cuenta := null;
            v_nom_cuenta     := null;
            v_cod_moneda     := null;
            select fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina,a.nro_cuenta, a.cod_moneda) cta_formateada,
                   fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta,
                   fug_obt_des_modal(a.cod_modulo,a.cod_modalidad) des_tip_cuenta,
                   a.denominacion nom_cuenta, a.cod_moneda cod_moneda
              into v_cta_formateada, v_cod_tip_cuenta, v_des_tip_cuenta, v_nom_cuenta, v_cod_moneda
              from ge_est_cuentas c,ge_cuentas a
             where a.nro_cuenta = trim(v_nro_cuenta)
               and a.cod_modulo = c.cod_modulo
               and a.cod_modalidad = c.cod_modalidad
               and a.estado = c.estado
               and c.activo = 'S'  -- solo cuentas activas
               and a.estado <> 'X'
               and a.cod_modalidad in (31,41); -- solo cuentas de ahorros y cuentas corrientes
            if p_cod_moneda <> v_cod_moneda then
               v_cod_res_cta := paj_bce.v_cod_cta_invalida;  -- moneda diferente
            else
               v_cod_res_cta := paj_bce.v_cod_aprobado;
            end if;
         exception
            when no_data_found then
               v_cod_res_cta := paj_bce.v_cod_cta_inexistente;
            when too_many_rows then
               v_cod_res_cta := paj_bce.v_cod_cta_duplicada;
            when others then
               v_cod_res_cta := paj_bce.v_cod_cta_invalida;
         end;
         if v_monto <= 0 and v_cod_res_cta = paj_bce.v_cod_aprobado then
            -- monto invalido
            v_cod_res_cta := paj_bce.v_cod_mto_invalido;
         end if;
         -- armo el detalle por cuenta
         v_detalles :=  v_detalles ||
                        lf_for_char(v_nro_cuenta,17)||
                        lf_for_char(v_cod_tip_cuenta,2)||
                        lf_for_char(v_des_tip_cuenta,35)||
                        lf_for_char(v_nom_cuenta,50)||
                        lf_for_char(rpad(v_cod_moneda,3,'.'),3)||
                        lf_for_money(v_monto,16)||
                        lf_for_char(v_cod_res_cta,3);
          -- registro el codigo de respuesta general, si hay errores en el detalle
          if v_cod_respuesta = paj_bce.v_cod_aprobado then
             if v_cod_res_cta <> paj_bce.v_cod_aprobado then
                v_cod_respuesta := '-88';-- v_cod_res_cta;
             end if;
          end if;
          If p_modo = 'C' then -- Es confirmacion y no hubo errores...
             insert into ge_pag_sueldos_tmp 
               (cod_ente, nro_cuenta, fec_envio, tipo, monto, estado)
             values
               (v_cod_ente, v_nro_cuenta, v_fec_actual, 'C', v_monto, 'H');
          End If;
     end loop;
   end if;
   if v_cod_respuesta = paj_bce.v_cod_aprobado then
      if v_tot_detalles <> p_tot_debito then
         v_cod_respuesta := paj_bce.v_cod_tot_invalido;
      end if;
   end if;
   If v_cod_respuesta != paj_bce.v_cod_aprobado then
      If p_modo = 'C' then -- Es confirmacion y no hubo errores...
         -- Al confirmar debe insertar en ge_pag_sueldos_tmp.
         pag_sue.LP_DEL_DATOS_TEMPORA(v_cod_ente, v_fec_actual, v_lugar);
      End if;
   Else
      If p_modo = 'C' then -- Es confirmacion y no hubo errores...
         insert into ge_pag_sueldos_tmp
           (cod_ente, nro_cuenta, fec_envio, tipo, monto, estado, tip_remuneracion)
         values
           (v_cod_ente, v_nro_cta_debito, v_fec_actual, 'D', p_tot_debito, 'H', p_tip_remuneracion);
         -- Actualiza todos los registros con el tipo de Remuneracion...
         update ge_pag_sueldos_tmp
            set tip_remuneracion = p_tip_remuneracion
          where cod_ente = v_cod_ente
            and fec_envio = v_fec_actual
            and fec_proceso is null;
         --   
         it_mail.mail(fug_obt_dir_correo,
                      'mpaiva@itbank.com.py,cgonzalez@itbank.com.py',
                      'Pago de Sueldos Pendiente',
                      'Pago de Sueldos ingresado por HomeBanking pendientes '|| chr(10) ||
                      'Codigo  : ' || v_cod_ente|| chr(10) ||
                      'Empresa : ' || v_des_ente|| chr(10) ||
                      'Monto   : ' || lf_for_money(p_tot_debito, 16)|| chr(10) ||
                      'Cantidad: ' || to_char(p_can_cuentas) || chr(10) ||
                      'Atentamente. '
                      );  
      End if;
   End if;
   -- siempre se responde con los detalles, sea o no sea con errores
   return lf_for_number(v_can_detalles,3)||
          v_detalles;
exception
  when others then
     raise_application_error(-20005,sqlerrm);
end; -- Pago de Sueldos
-- Pago a Proveedores
function fu_pro_operacion_075(p_parametros in varchar2)
  return clob is
-- datos recibidos
p_modo           varchar2(1)  := substr(p_parametros,28,1);             -- modo de control
p_cod_ente       number(5)    := substr(p_parametros,29,5);
v_fec_pago1      varchar2(10) := trim(substr(p_parametros, 34, 10));
v_fec_pago2      varchar2(10) := trim(substr(p_parametros, 44, 10));
p_fec_pago1      date;
p_fec_pago2      date;
p_can_orden      number(5)    := substr(p_parametros,54,5);
p_can_factura    number(5)    := substr(p_parametros,59,5);
p_det_orden      clob;--         := substr(p_parametros, 44, 105*p_can_orden);
p_det_factura    clob;--         := substr(p_parametros, 44, 74*p_can_orden);
-- datos de los detalles
v_nro_cuenta     varchar2(17);      -- contiene los numeros de cuentas
v_monto          number(18,2);      -- monto del credito
-- datos a responder
v_tot_detalles   number(18,2) := 0; -- total a debitar
v_can_detalles   number(3)    := 0; -- cantidad de cuentas
--
v_detalles       clob := null; -- datos de las cuentas
---
v_cod_ente       number(6);         -- codigo del ente
v_des_ente       varchar2(100);     -- descripcion del ente
v_formato        varchar2(30);      -- formato de archivo
v_res_principal  varchar2(03) := '000'; -- respuesta
---
v_lugar          varchar2(2000);
v_indice         number(5);
v_tip_comprobante ge_pag_proveedores_tmp.tip_comprobante%type;
r_orden          ge_pag_proveedores_tmp%rowtype;
r_factu          ge_pag_pro_facturas_tmp%rowtype;
v_error          varchar2(2000);
v_nro_orden      ge_pag_pro_facturas_tmp.nro_orden%type;
v_tip_cobro      varchar2(1);
Cursor c_detalle is Select nro_orden, nro_factura, tip_comprobante, for_pago, nro_cheque, nro_cta_credito, 
                         fec_ingreso, fec_pago, monto, nro_recibo, beneficiario, 
                         decode(cod_proceso, 0, 'Aprobado', InitCap(concepto)) concepto, estado, 
                         cod_usu_operador, cod_ente, cod_proceso, cod_moneda, 
                         tip_carga, nvl(f_cantidad, 0) f_cantidad
                    from ge_pag_proveedores_tmp, (Select cod_ente f_cod_ente, nro_orden f_nro_orden, count(*) f_cantidad
                                                    from ge_pag_pro_facturas_tmp
                                                   where cod_ente = p_cod_ente
                                                     and trunc(fec_insercion) = trunc(sysdate)
                                                     and usu_insercion = user
                                                   Group by cod_ente, nro_orden)
                   where f_cod_ente(+) = cod_ente
                     and f_nro_orden(+) = nro_orden
                     and cod_ente = p_cod_ente
                     and cod_usu_operador = user
                     and tip_carga = 'H';
Cursor c_det_fac is Select nro_orden, fec_carga, nro_factura, 
                           mto_total, concepto, cod_ente
                      from ge_pag_pro_facturas_tmp
                     where cod_ente = p_cod_ente
                       and trunc(fec_insercion) = trunc(sysdate)
                       and nro_orden = v_nro_orden;
begin
   -- 1. valido la clave del cliente
   pr_val_clave(p_parametros);
   If v_fec_pago1 is not null then
      p_fec_pago1 := to_date(v_fec_pago1, 'DD/MM/YYYY');
      if p_fec_pago1 < v_fec_actual then
         v_cod_respuesta := paj_bce.v_cod_can_invalida;
      end if;
   else
     v_cod_respuesta := paj_bce.v_cod_can_invalida; 
   End if;
   If v_fec_pago2 is not null then
      p_fec_pago2 := to_date(v_fec_pago2, 'DD/MM/YYYY');
      if p_fec_pago2 <= p_fec_pago1 then
         v_cod_respuesta := paj_bce.v_cod_can_invalida;
      end if;   
   End if;
   -- 2. Verifico si la persona tiene el servicio de pago de sueldos
   if v_cod_respuesta = paj_bce.v_cod_aprobado then
     begin
        select a.cod_ente, a.descripcion,
               fug_obt_parentes(a.cod_ente,'TIP_COB_PPROV')
          into v_cod_ente, v_des_ente, v_tip_comprobante
          from ge_entes a
         where a.cod_persona = v_cod_persona
           and a.tipo = 'PR'
           and a.cod_ente = p_cod_ente
           and fug_obt_parentes(a.cod_ente,'SER_ACTIVO_PRV') = 'S'
           and fug_obt_parentes(a.cod_ente,'HAB_HOMEBANKING_PRV') = 'S';
        ---   
        if v_tip_comprobante != 'O' and p_can_factura > 0 then
           v_cod_respuesta := paj_bce.v_cod_sin_factura;
        elsif v_tip_comprobante = 'O' and p_can_factura = 0 then
           v_cod_respuesta := paj_bce.v_cod_con_factura;
        end if;
     exception
        when too_many_rows then
           v_cod_respuesta := paj_bce.v_cod_cta_duplicada;
        when others then
            v_cod_respuesta := paj_bce.v_cod_sin_autorizacion;
     end;
   end if;
   -- 3. Tomo la cantidad de cuentas recibidas
   if v_cod_respuesta = paj_bce.v_cod_aprobado then
     --- lee las ordenes de pago
     pag_prv.PR_ELI_PROV_TMP(p_cod_ente);
     pag_prv.PR_ELI_FAC_TMP(p_cod_ente);
     v_indice := 1;
     v_tip_comprobante := fug_obt_parentes(p_cod_ente, 'TIP_COB_PPROV');
     If p_can_orden > 0 then
       p_det_orden := substr(p_parametros, 64, 108*p_can_orden);
       for i in 1..p_can_orden loop
          ----
          r_orden := null;
          r_orden.nro_orden := to_number(substr(p_det_orden, v_indice, 10)); v_indice := v_indice + 10;
          r_orden.nro_factura := trim(substr(p_det_orden, v_indice, 10)); v_indice := v_indice + 10;
          r_orden.tip_comprobante := v_tip_comprobante; -- Toma del parametro del Ente....
          r_orden.for_pago := trim(substr(p_det_orden, v_indice, 1)); v_indice := v_indice + 1;
          r_orden.nro_cheque := null;
          r_orden.nro_cta_credito := trim(substr(p_det_orden, v_indice, 15)); v_indice := v_indice + 15;
          r_orden.fec_ingreso := v_fec_actual;
          r_orden.fec_pago := null;
          r_orden.monto := to_number(substr(p_det_orden, v_indice, 18)); v_indice := v_indice + 18;
          r_orden.nro_recibo := null;
          r_orden.beneficiario := trim(substr(p_det_orden, v_indice, 50)); v_indice := v_indice + 50;
          r_orden.concepto := null;
          r_orden.estado := 'C';
          r_orden.cod_usu_operador := user;
          r_orden.cod_ente := p_cod_ente;
          r_orden.cod_proceso := null;
          r_orden.cod_moneda := trim(substr(p_det_orden, v_indice, 3)); v_indice := v_indice + 3;
          r_orden.tip_carga := 'H';
          ----
          insert into ge_pag_proveedores_tmp
          (nro_orden, nro_factura, tip_comprobante, for_pago, nro_cheque, 
           nro_cta_credito, fec_ingreso, fec_pago, monto, nro_recibo, 
           beneficiario, concepto, estado, cod_usu_operador, 
           cod_ente, cod_proceso, cod_moneda, tip_carga)
          values
          (r_orden.nro_orden, r_orden.nro_factura, r_orden.tip_comprobante, r_orden.for_pago, r_orden.nro_cheque, 
           r_orden.nro_cta_credito, r_orden.fec_ingreso, r_orden.fec_pago, r_orden.monto, r_orden.nro_recibo, 
           r_orden.beneficiario, r_orden.concepto, r_orden.estado, r_orden.cod_usu_operador, 
           r_orden.cod_ente, r_orden.cod_proceso, r_orden.cod_moneda, r_orden.tip_carga
           );
       end loop;
       --- lee las facturas
       If p_can_factura > 0 then
         p_det_factura := substr(p_parametros, (64+v_indice-1), 74 * p_can_factura);
         v_indice := 1;
         for i in 1..p_can_factura loop
            -- Leo las facturas....
            r_factu.nro_orden   := to_number(substr(p_det_factura, v_indice, 10)); v_indice := v_indice + 10;
            r_factu.nro_factura := trim(substr(p_det_factura, v_indice, 10)); v_indice := v_indice + 10;
            r_factu.mto_total   := to_number(substr(p_det_factura, v_indice, 18)); v_indice := v_indice + 18;
            r_factu.concepto    := trim(substr(p_det_factura, v_indice, 35)); v_indice := v_indice + 35;
            r_factu.cod_ente    := p_cod_ente;
            r_factu.fec_carga   := null;
            insert into ge_pag_pro_facturas_tmp 
                (nro_orden, fec_carga, nro_factura, mto_total, concepto, cod_ente)
            values
                (r_factu.nro_orden, r_factu.fec_carga, r_factu.nro_factura, r_factu.mto_total, r_factu.concepto, r_factu.cod_ente);
         end loop;
       End if;
       --- Una vez que carga todo va a validar....
       pag_prv.PR_VER_DAT_TMP(p_cod_ente, p_fec_pago1, p_fec_pago2, v_error, 'N');
       If v_error is not null then
          v_cod_respuesta := '-88';
       End if;
       v_detalles := null;
       v_can_detalles := p_can_orden;
       For r1 in c_detalle Loop
          v_detalles := v_detalles ||
                lpad(r1.nro_orden, 10, ' ')|| 
                lpad(r1.nro_factura, 10,' ')||
                r1.for_pago||
                lpad(nvl(r1.nro_cta_credito,' '), 15, ' ')||
                lpad(r1.monto, 18, '0')||
                rpad(nvl(r1.beneficiario,' '), 50, ' ')||
                rpad(nvl(r1.cod_moneda, ' '), 3, ' ')||
                rpad(r1.concepto, 40, ' ')||
                rpad(r1.cod_proceso, 3, '0')||
                lpad(r1.f_cantidad, 3, '0');
          -- Por cada factura lee el detalle de las facturas si es que posee...
          v_nro_orden := r1.nro_orden;
          If r1.f_cantidad > 0 then
            For r2 in c_det_fac Loop
                v_detalles := v_detalles||
                lpad(r2.nro_orden, 10, ' ')|| 
                lpad(nvl(r2.nro_factura, ' '), 10,' ')||
                lpad(nvl(r2.mto_total,0), 18, '0')||
                rpad(nvl(r2.concepto, ' '), 35, ' ')
                ;                
            End Loop;      
          End if;
       End Loop;
       ---
       If v_cod_respuesta = paj_bce.v_cod_aprobado and p_modo = 'C' then
          pag_prv.PR_VER_DAT_TMP(p_cod_ente, p_fec_pago1, p_fec_pago2, v_error, 'S');
          if v_error is not null then
             v_cod_respuesta := paj_bce.v_cod_cta_duplicada;
          End if;
       End if;
     else
       v_cod_respuesta := paj_bce.v_cod_cta_inexistente;
     end if;   

   end if;
   -- siempre se responde con los detalles, sea o no sea con errores
   return lf_for_number(v_can_detalles,3)||
          v_detalles;
exception
  when others then
    if sqlcode <= -20000 then
        raise;
    else
        raise_application_error(-20005,sqlerrm);
    end if;
end; -- Pago a Proveedores.

-- cambio de clave del cliente
function fu_pro_operacion_080(p_parametros in varchar2)
  return varchar2 is
-- datos recibidos
v_cla_nueva varchar2(10) := substr(p_parametros,28,10); -- nueva clave
begin
   -- 1. valido la clave del cliente
   pr_val_clave(p_parametros);
   -- 2. Control de la clave nueva
   if length(trim(v_cla_nueva)) = 0 then
      -- no viene la clave nueva
      v_cod_respuesta := paj_bce.v_cod_pin_invalido;
   elsif v_cla_nueva = p_clave then
      -- clave igual a la anterior
      v_cod_respuesta := paj_bce.v_cod_pin_invalido;
   else
      -- aprobado
      v_cod_respuesta := paj_bce.v_cod_aprobado;
      -- actualizo la nueva clave
      begin
        update ge_clientes a
           set clave = v_cla_nueva,  -- nueva clave
               fec_est_clave = decode(est_clave,'N',sysdate,'M',sysdate,fec_est_clave), --fecha de cambio de estado
               est_clave = decode(est_clave,'N','A','M','A',est_clave) -- nuevo a activo
         where cod_persona = v_cod_persona;
        if sql%notfound then
          v_cod_respuesta := paj_bce.v_cod_pin_invalido;
        end if;
        commit;
      exception
        when others then
          v_cod_respuesta := paj_bce.v_cod_pin_inexistente;
      end;
   end if;
   return ' ';  -- nada
end;
-- fin del cambio de clave
-- Mensaje a la entidad
function fu_pro_operacion_081(p_parametros in varchar2)
  return varchar2 is
-- datos recibidos
v_nro_sobre varchar2(10) := substr(p_parametros,28,10); -- sobre del mensaje
--
begin
   -- 1. valido la clave del cliente
   pr_val_clave(p_parametros);
   -- 2. aprobado, se genera un movimiento
   if  v_cod_respuesta = paj_bce.v_cod_aprobado then
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
      r_gmovi.nro_documento2  := v_cod_persona;
      r_gmovi.cod_tasa        := null;
      r_gmovi.val_tasa        := null;
      r_gmovi.cotizacion      := null;
      r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        :=  'Mensaje del cliente';
      r_gmovi.est_cuenta      := null;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.nro_caja        := paj_bce.v_nro_terminal;
      -- genero el movimiento por cambio de estado
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
   end if;
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
v_modo            varchar2(1) := substr(p_parametros,28,1);
v_cod_servicio    varchar2(3) := substr(p_parametros,29,3);   --

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
v_nro_cta_debito  varchar2(17) := trim(substr(p_parametros,32,17));
v_cod_mon_debito  varchar2(4);
v_nro_sobre       number(10) := trim(substr(p_parametros, 49,10));
v_efectivo varchar2(100)  := substr(p_parametros, 59,18);
v_imp_efectivo    number(18,2) := nvl(to_number(replace(trim(substr(p_parametros, 59,18)),',','.')),0); -- efectivo
v_imp_che_n_bco   number(18,2) := nvl(to_number(replace(trim(substr(p_parametros, 77,18)),',','.')),0); -- che.ntro.bco
v_imp_che_o_bco   number(18,2) := nvl(to_number(replace(trim(substr(p_parametros, 95,18)),',','.')),0); -- che otros bcos.
v_imp_debito      number(18,2) := nvl(to_number(replace(trim(substr(p_parametros, 113,18)),',','.')),0);   -- debito
v_tot_pago        number(18,2) := nvl(to_number(replace(trim(substr(p_parametros, 131,18)),',','.')),0);   -- total
--
v_cta_for_debito  varchar2(17);  -- cuenta formateada
v_est_cta_debito  varchar2(1);   -- estado de la cuenta
v_cod_mod_debito  number(4);     -- modulo de la cuenta
v_cod_mad_debito  number(4);     -- modalidad de la cuenta
v_cod_ofi_debito  number(4);     -- oficina de la cuenta
v_nvo_est_debito  varchar2(1) := null; -- cambio de estado de cuenta
v_cot_debito      number(18,2) := null;
v_nom_cta_debito  varchar2(100);
v_cotizacion      ge_cotizaciones.val_conversion%type;
r_par ge_cob_ser_parametros%rowtype;
---
v_can_dias       number(3);--   := substr(p_parametros,28,2);   -- cantidad de dias
v_ver_todas      varchar2(3);-- := substr(p_parametros,30,1);   -- ver todas las cuentas s/n
r_cobro          GE_COB_SERVICIOS%ROWTYPE;
v_nro_cuenta     varchar2(17);
begin
  -- 1. valido la clave del cliente
  pr_val_clave(p_parametros);
  -- 2. busco los datos de la cuentas
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
       if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
           v_cod_respuesta := paj_bce.v_cod_cta_inexistente;
     end;
  end if;
  if v_cod_respuesta = paj_bce.v_cod_aprobado then

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
               v_cod_respuesta := paj_bce.v_cod_mto_invalido;
             elsif nvl(v_imp_efectivo,0) + nvl(v_imp_che_n_bco,0) +
                   nvl(v_imp_che_o_bco,0) + nvl(v_imp_debito,0) <> nvl(v_tot_pago,0) then
                   -- total depositado invalido
                   v_cod_respuesta := paj_bce.v_cod_tot_invalido;
             end if;
          end if;
        exception
          when others then
             -- monto invalido
             v_cod_respuesta := paj_bce.v_cod_mto_invalido;
        end;
        if v_cod_respuesta = paj_bce.v_cod_aprobado then
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
                v_cod_respuesta := paj_bce.v_cod_tra_invalida;
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

              if v_cod_respuesta = paj_bce.v_cod_aprobado then -- sino hubo ERROR se arma los datos para grabar
                pag_Ser.pr_ins_cobro( r_cobro, pag_ser.g_cod_transaccion, 'E' );
                if to_number(v_cod_respuesta) = 0 then
                   v_cod_respuesta := paj_bce.v_cod_aprobado;
                end if;

             End if;
            if v_imp_efectivo > 0 then
               -- importe en efectivo
                v_cod_tra_padre   := 215;
                v_cod_transaccion := 613;
                v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
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
                v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
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
                v_cod_transaccion := 615;
                v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
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
                                   'O', -- cheque otros bcos
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
  if v_cod_respuesta = paj_bce.v_cod_aprobado then
     -- todo ok, se arma el mensaje de respuesta
     return lf_for_number(v_cod_persona,7);
  else
     return null;  -- nada
  end if;
end;  -- Fin de consulta de codigo de cliente
end paj_bce;
/

