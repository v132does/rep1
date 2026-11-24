CREATE OR REPLACE FUNCTION IT.fut_val_req_pre_aprobados ( p_cod_persona varchar2, -- Codigo de la persona
                                                      p_online varchar2 default 'S'
                                                     ) return boolean is
/**
  ----
  -- Author  : CNOGUERA
  -- Created : 20/01/2015
  -- Purpose : Función a utilizar para validar los requisitos para Prestamos Pre-Aprobados vía ATM
               Esta función realizará las validaciones para determinar si un un Pre-Aprobado reúne
               las condiciones para ser desembolsada en un ATM. Esta validación será para el Inicio de Día.
               También, en la misma función se realizará la validación online que será determinado
               por un parámetro de la función para determinar el tipo de evaluación a realizar.
**/
  v_result          boolean := true;
  -- Variables --
  v_dia_atraso      number;
  v_cat_riesgo      number;
  v_cat_subjetiva   number;
  v_cat_sistema     number;
  v_can_prestamos   number;
  v_can_tarjetas    number;
  v_can_pre         number;
  v_fec_actual      date:= pag_cal.FU_OBT_FEC_ACTUAL(6);

  -- Funcion para obtener la cantidad de préstamos activos --
  function lf_obt_can_prestamo( p_cod_persona in varchar2 ) return number is
  v_result number:=0;
    v_denominacion varchar2(100);
    v_existe varchar2(1):='N';
 cursor datos is
     select p.nro_solicitud,p.cod_modulo,p.cod_modalidad, d.cod_campana,d.denominacion
      from pr_cta_prestamos p, ge_cta_clientes c,ge_pro_pre_aprobados d
     where nvl( p.estado, 'X' ) <> 'N'
       and nvl( c.relacion, 'P' ) = 'P'
       and c.cod_persona = p_cod_persona
       and trunc(sysdate)-p.fec_inicio <= /*180*/fug_obt_pardinamico('CAN_MAX_DIA_TARJETA') -- DYDMR-9673
       and p.nro_cuenta = c.nro_cuenta
       and p.cod_sub_modalidad <> '99'
       --
       and p.nro_solicitud=d.nro_solicitud;

  begin
      -- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- 10/2016 --
      -- Se deben excluir las validaciones otorgamiento de prestamos en los últimos 180 días,
      -- siempre y cuando el préstamo otorgado fue bajo la misma denominacion(CCP) la cual se quiere otorgar.
      --Buscamos si el cliente tiene un pre-aprobado vigente de la modalidad 68
      v_existe:='N';
        begin
         select  'S',a.denominacion
           into  v_existe, v_denominacion
            from ge_pro_pre_aprobados a
               where a.cod_modalidad= fug_obt_pardinamico('PRE_MAD_PRE_APROBADOS')
                     and a.cod_persona= p_cod_persona
                     and a.estado='V'
                     and a.nro_solicitud is null
                     and rownum=1;
        exception
          when no_data_found then
            v_existe:='N';
          when others then
            v_existe:='N';
        end;
     if v_existe ='S' then
          v_result:=0;
          FOR dat IN datos LOOP
              --Buscamos los datos del pre-aprobado vigente
              --Sino es nulo(Se puede comparar) y son distintos
                  if v_denominacion is not null and dat.denominacion is not null then
                    if UPPER(TRIM(v_denominacion)) <> UPPER(TRIM(dat.denominacion)) then
                       --Tiene prestamos de otra denominacion
                       v_result:= nvl(v_result,0)+1;
                    end if;
                  end if;
          end loop;
    else
      --Sino tiene pre-aprobado 68 vigente no puede otorgarse
       v_result:=1;
    end if;
   --
    return nvl(v_result,0);
  exception
    when others then
      return 0;
  end lf_obt_can_prestamo;

  --Funcion para obtener la cantidad de días transcurridos desde la fecha de ultima apertura de cuenta de TC hasta la fecha --
  function lf_obt_can_dia_tarjeta( p_cod_persona in varchar2 ) return number is
    v_result number;
  begin
     select nvl((pag_cal.fu_obt_fec_actual(1)-max(t.fec_apertura)),181) can_dias --para que pase 180 sino tiene cuenta de tarjetas
      into v_result
      from ta_cta_tarjetas t, ge_cta_clientes c/*,
           GE_PRO_CAMPANAS s,  ge_pro_pre_aprobados a*/ --DYDMR-9673 Se comenta las tablas de pre-aprobados
     where t.nro_cuenta = c.nro_cuenta                 -- para que contemple todas las tdc
       and c.cod_persona = p_cod_persona
       and t.estado != 'C'
       and c.relacion = 'P'
       and nvl(fug_obt_pardinamico('MAD_TAR_EXC_PREAPR',t.cod_modulo,t.cod_modalidad),'N') = 'N'
      /* and c.cod_persona = a.cod_persona
       and t.cod_modulo = a.cod_modulo
       and a.estado = 'V'
       and a.nro_solicitud is null
       and t.nro_solicitud = s.nro_solicitud(+)
       and nvl(s.denominacion,'xx') != nvl(a.denominacion,'yy')*/;
  --
    return nvl(v_result,0);
  exception
    when no_data_found then
      return 181; --para que pase 180 sino tiene cuenta de tarjetas
    when others then
      return 0;
  end lf_obt_can_dia_tarjeta;

  --Funcion para validar cuenta de nomina en GS para prestamos pre-aprobados
  --Retorna 1 si esta Ok
  -- 0 Sino tiene cuenta en Gs relacionada
  function lf_val_cta_cliente( p_cod_persona in varchar2 ) return number is
    v_result number;
    v_existe varchar2(1):='N';
   cursor datos is
      Select ah.nro_cuenta
              from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
             where cl.nro_cuenta = ah.nro_cuenta
               and cl.cod_modulo = g.cod_modulo
               and cl.cod_modalidad = g.cod_modalidad
               and ah.estado = g.estado
               and ah.estado in ('A','N')
               and g.activo = 'S'
               and cl.relacion = 'P'
               and ah.cod_ente is not null
               and ah.cod_moneda = pag_gen.FU_OBT_MON_LOCAL --Moneda Local
               and cl.cod_persona=p_cod_persona
     union
        Select cc.nro_cuenta
              from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
             where cc.nro_cuenta = cl.nro_cuenta
               and cl.cod_modulo = g.cod_modulo
               and cl.cod_modalidad = g.cod_modalidad
               and cc.estado = g.estado
               and cc.estado in ('A','N')
               and g.activo = 'S'
               and cl.relacion = 'P'
               and cc.cod_ente is not null
               and cc.cod_moneda = pag_gen.FU_OBT_MON_LOCAL --Moneda Local
               and cl.cod_persona=p_cod_persona;
  begin
       v_result:=0;
        --Buscamos si tiene prestamo pre-aprobado activo para validar
       v_existe:='N';
        begin
         select  'S'
           into  v_existe
            from ge_pro_pre_aprobados a
               where a.cod_modalidad= fug_obt_pardinamico('PRE_MAD_PRE_APROBADOS')
                     and a.cod_persona= p_cod_persona
                     and a.estado='V'
                     and a.nro_solicitud is null
                     and rownum=1;
        exception
          when no_data_found then
            v_existe:='N';
          when others then
            v_existe:='N';
        end;

     IF v_existe ='S' then
        v_result:=0;
        FOR dat IN datos LOOP
            v_result:=1;
        end loop;
     else
       --Sino tiene prestamos pre-aprobado retornamos 1 Ok
       v_result:=1;
     end if;
   --
    return nvl(v_result,1);
  exception
    when no_data_found then
      return 1;
    when others then
      return 1;
  end lf_val_cta_cliente;

begin

  if p_online != 'S' then  -- Inicio Día --
    /**
    Las condiciones a validar para el Inicio Día serán las siguientes:
    1) Debe estar al día en todos los productos que posea en el Banco = 0 días de atraso.
    2) Categoría CRC BCP, en BBVA la categoría de previsión y la categoría subjetiva = 1 y en Resto del Sistema = 1
    3) Que el valor del monto Preaprobado en ITGF no sea de Gs 1 (un guaraní).
    4) Sin inhibiciones en ITGF

    **/
    -- 1) Días de Atraso = 0 --
    v_dia_atraso := fug_obt_atraso(p_cod_persona,'A');
    if nvl(v_dia_atraso,0) > 0 then
     return false;
    end if;
    -- 2) Categoría Riesgo = 1, Categoría Subjetiva = 1, Categoría Sistema = 1 --
    select a.cat_riesgo, a.cat_subjetiva, a.cat_sistema
      into v_cat_riesgo, v_cat_subjetiva, v_cat_sistema
      from ge_clientes a
     where cod_persona = p_cod_persona;
    if nvl(v_cat_riesgo,1)!=1 or nvl(v_cat_subjetiva,1)!=1 or nvl(v_cat_sistema,1)!=1 then
     return false;
    end if;
    -- 3) Monto Aprobado debe ser mayor a 1
    select count(*)
      into v_can_pre
      from ge_pro_pre_aprobados a
     where a.cod_persona = p_cod_persona
       and nvl(a.min_monto,a.max_monto) <= 1
       and a.estado = 'V'
       and nvl(fug_obt_pardinamico('MOD_PRE_APR_ATM_WEB',a.cod_modulo,a.cod_modalidad),'N') = 'S'  -- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- 10/2016 --
       and a.nro_solicitud is null
       and ( a.cod_campana in( select distinct c.cod_campana
                                 from cr_campanas c
                                where v_fec_actual >= c.fec_inicio
                                  and ( v_fec_actual <= c.fec_vencimiento or c.fec_vencimiento is null )
                               )
             or a.cod_campana is null )
         and a.lote = ( select max(x.lote)
                        from ge_pro_pre_aprobados x
                       where x.cod_persona = a.cod_persona
                         and x.estado = 'V'
                         and x.cod_modulo = a.cod_modulo
                         and x.cod_modalidad = a.cod_modalidad
                         and x.nro_solicitud is null
                         and ( x.cod_campana = a.cod_campana
                               or x.cod_campana is null ) );
    if nvl(v_can_pre,0) > 0 then
     return false;
    end if;

    -- 1) Persona Inhibida = 'N' -- Flexibilidad
    if fug_obt_es_per_inhi(p_cod_persona) = 'S' then
       return false;
    end if;


  else
    /**
    La evaluación online será para los siguientes casos:
    1) Sin inhibiciones en ITGF
    2) Sin préstamos (en todas sus modalidades incluyendo descuentos de cheques) y Tarjetas de Crédito otorgados en los últimos 180 días.
    3) Sin solicitudes pendientes de liquidación o anulación (solicitudes que todavía permitan el otorgamiento de un producto). Se aplica a préstamos y tarjetas.
    **/
    -- 1) Persona Inhibida = 'N' --
    if fug_obt_es_per_inhi(p_cod_persona) = 'S' then
     return false;
    end if;
    -- 2) Cantidad de Préstamos Activos = 0 --

    v_can_prestamos := lf_obt_can_prestamo(p_cod_persona);
   if nvl(v_can_prestamos,0) > 0 then
     return false;
    end if;
    -- 2) Tarjetas de Crédito otorgados en los últimos 180 días -- 90 días
    v_can_tarjetas := lf_obt_can_dia_tarjeta(p_cod_persona);
    if nvl(v_can_tarjetas,0) <= fug_obt_pardinamico('CAN_MAX_DIA_TARJETA') then --180 --DYDMR-9673 se crea el par_dinamico para configurar la cantidad de dias
     return false;
    end if;
    -- 3) Solicitud de Préstamo en Estado Solicitado o Pendiente de Liquidación o Anulación --
    select count(*)
      into v_can_prestamos
      from pr_solicitudes a
     where a.cod_persona = p_cod_persona
       and a.estado in('S','L'); --Estado de la Solicitud. (S = Solicitada / L = Pendiente de Liquidación / A = Desembolsada / N = Cancelada / R = Rechazada).
    if nvl(v_can_prestamos,0) > 0 then
     return false;
    end if;
    -- 3) Solicitud de Tarjeta Pendiente de Liquidación o Anulación --
    select count(*)
      into v_can_tarjetas
      from ta_solicitudes a
     where a.cod_persona = p_cod_persona
     --BWP-832 glopez
       and a.cod_estado not in('TIA','RCH','ANU', 'APR'); ---- ver en la tabla ge_sol_estados
    if nvl(v_can_tarjetas,0) > 0 then
     return false;
    end if;
  end if;

  /*WA: 14/07/2017 Se valida On-Line y Normal
     Si es cliente nómina que la cuenta relacionada sea en Gs
     Para préstamos pre_aprobados*/
  if fug_es_cli_nomina(p_cod_persona,null)='S' then
     if lf_val_cta_cliente(p_cod_persona)<> 1 then
        return false;
     end if;
  end if;
  return v_result;
exception
 when others then
   return false;
end fut_val_req_pre_aprobados;
/

