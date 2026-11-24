create or replace function it.FUJ_PRO_TRANSACCION_121(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_tra_padre   in varchar2, -- Codigo de transaccion
      p_hora            in varchar2 default null, -- hora de la transaccion a reimprimir
      p_nro_boleta      in varchar2 default null)
return long is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 121;        -- Transaccion
  --
  v_mod_cobro number(3);               -- Caja
  v_mad_cobro number(3);           -- Caja
  --
  v_cod_usuario varchar2(10) := upper(user); -- usuario
  --
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);          -- saldo actual de la caja en cheques
  --
  v_msj_salida        varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta     varchar2(03) := '000'; -- sin errores
  v_msj_respuesta     long         := 'Operacion Confirmada'; -- sin errores
  --
  v_tipo              varchar2(01);  -- Debito para la caja (ingreso)
  v_tip_monto         varchar2(01);  -- E/efectivo C-cheq
  v_nro_secuencia     number(3) := 0;  -- secuencia del mov.
  --
  v_cantidad          number(3) := 0;
  --
  r_gmovi             ge_movimientos%rowtype;
  v_sentencia         varchar2(1000);
  v_parametros        varchar2(500);
  v_cod_oficina       cj_movimientos.cod_oficina%type;
  v_nro_operacion     cj_movimientos.nro_documento%type;
  v_nro_cuenta        cj_movimientos.nro_cuenta%type;  
  v_nro_factura       ge_movimientos.referencia%type;
  v_nro_recibo        ge_movimientos.nro_documento%type;
  v_nro_caja          cj_movimientos.nro_caja%type;
  v_cod_moneda        cj_movimientos.cod_moneda%type;
  v_fecha             cj_movimientos.fecha%type;
  v_hora              cj_movimientos.hora%type;
 
  
  -- Procedimiento interno para generar movimiento y act. de control de caja
  --por ahora no se genera, sólo se imprimen las operaciones autorizadas
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja
      update cj_controles
         set estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;
      -- genero el movimiento por el  cheque
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento, nro_cuenta, monto, tip_monto, tipo,nro_doc_referencia)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1, -- secuencia 1
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
          v_nro_operacion, v_nro_cuenta, 0,'E' /* cheq.otros bcos */, v_tipo,
          null); /* no es debito ni credito */
  end lp_gen_transaccion;

function lf_val_imp_ope_riesgo return varchar is
 v_tra_hab_impresion varchar2(1) := 'N';
begin
 begin
   
 select est_operacion
  into v_tra_hab_impresion  
from(
 select 'S' est_operacion
   from ge_par_ope_riesgos r
  where r.cod_modulo = v_cod_modulo
    and r.cod_modalidad = v_cod_modalidad
    and r.cod_transaccion = to_number(p_cod_tra_padre)
    and exists (select distinct 1
           from ge_mov_autorizaciones u
          where u.cod_mod_padre = r.cod_modulo
            and u.cod_mad_padre = r.cod_modalidad
            and u.cod_tra_padre = r.cod_transaccion
            and u.cod_usuario = v_cod_usuario
            and u.hora = p_hora
            and u.estado = 'A')
  union
  select 'R' est_operacion
   from ge_par_ope_riesgos r
  where r.cod_modulo = v_cod_modulo
    and r.cod_modalidad = v_cod_modalidad
    and r.cod_transaccion = to_number(p_cod_tra_padre)
    and exists (select distinct 1
           from ge_mov_autorizaciones u
          where u.cod_mod_padre = r.cod_modulo
            and u.cod_mad_padre = r.cod_modalidad
            and u.cod_tra_padre = r.cod_transaccion
            and u.cod_usuario = v_cod_usuario
            and u.hora = p_hora
            and u.estado = 'R')
   union 
   select 'P' est_operacion
     from ge_par_ope_riesgos r
    where r.cod_modulo = v_cod_modulo
      and r.cod_modalidad = v_cod_modalidad
      and r.cod_transaccion = to_number(p_cod_tra_padre)
      and exists (select distinct 1
             from ge_mov_autorizaciones u
            where u.cod_mod_padre = r.cod_modulo
              and u.cod_mad_padre = r.cod_modalidad
              and u.cod_tra_padre = r.cod_transaccion
              and u.cod_usuario = v_cod_usuario
              and u.hora = p_hora
              and u.estado = 'S')
    );     
 exception
   when no_data_found then
     v_tra_hab_impresion := 'N';
     return v_tra_hab_impresion;
   when others then
     v_tra_hab_impresion := 'N';
     return v_tra_hab_impresion;
 end;
 
 return v_tra_hab_impresion;
exception
 when others then
   v_tra_hab_impresion := 'N';
   return v_tra_hab_impresion;

end lf_val_imp_ope_riesgo;
 
procedure lp_act_can_impresion is
 
begin
 update cj_movimientos c
    set c.can_impresion = nvl(c.can_impresion, 0) + 1
  where c.fecha = v_fec_actual
    and c.cod_usuario = v_cod_usuario
    and c.hora = v_hora
    and c.cod_tra_padre = to_number(p_cod_tra_padre);
exception
 when no_data_found then
   v_cod_respuesta := '006'; -- error
   v_msj_respuesta := 'ERROR: Al actualizar movimiento de Caja.';
 when others then
   v_cod_respuesta := '006'; -- error
   v_msj_respuesta := 'ERROR: Al actualizar movimiento de Caja.';
end lp_act_can_impresion;
 
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido los datos ingresados
 if to_number(p_cod_tra_padre) is  null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Transacción a imprimir.';
 elsif lf_val_imp_ope_riesgo  = 'P' then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Operación Pendiente de Aprobación, no se puede imprimir.';
 elsif lf_val_imp_ope_riesgo  = 'R' then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Operación Rechazada, no se puede imprimir.';    
 elsif lf_val_imp_ope_riesgo  = 'N' then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Operación no es de Riesgo, no se puede imprimir.';
 elsif p_hora is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la hora de la Operación. Presione F9 para ver Lista de Operaciones';
 else
    -- Obtengo los datos de la caja
      prj_obt_datos_caja(p_nro_caja,
                         v_cod_moneda,
                         v_cod_oficina,
                         v_fec_caja,
                         v_estado,
                         v_sal_actual,
                         v_sal_cheques);
                         
    -- Datos del movimiento a imprimir
   select count(*)
     into v_cantidad
     from cj_movimientos b
    where b.cod_usuario = v_cod_usuario
      and b.cod_tra_padre = to_number(p_cod_tra_padre)
      and b.nro_caja = to_number(p_nro_caja)
      and hora = p_hora
      and b.estado = 'N'
      and nvl(b.can_impresion, 0) = 0;

    if v_cantidad = 0 then
       v_cod_respuesta := '001'; -- error
       v_msj_respuesta := 'ERROR: No existe comprobante a imprimir.';
    else
     select cj.nro_documento, cj.cod_moneda, cj.nro_cuenta, cj.cod_oficina,
            cj.nro_caja, cj.fecha, cj.hora
       into v_nro_operacion, v_cod_moneda, v_nro_cuenta, v_cod_oficina, 
            v_nro_caja, v_fecha, v_hora          
       from cj_movimientos cj
      where nro_caja = to_number(p_nro_caja)
        and hora = p_hora
        and cod_tra_padre = to_number(p_cod_tra_padre)
        and estado = 'N' -- normal
        and cod_usuario = v_cod_usuario
        and rownum = 1;

       if  lf_val_imp_ope_riesgo  = 'S' then
       
        If to_number(p_cod_tra_padre) = 250 then 
             v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
       
              FUJ_IMP_COMPROBANTE_250(v_nro_operacion, v_cod_oficina, v_nro_caja);
              v_cod_respuesta := 'IMP'; 
              
         elsif to_number(p_cod_tra_padre) = 251 then -- ADELANTO EN EFECTIVO - tARJ CRED
             v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
        
             FUJ_IMP_COMPROBANTE_251 (v_nro_operacion,  v_cod_oficina, v_nro_caja);
             v_cod_respuesta := 'IMP'; 
             
         elsif to_number(p_cod_tra_padre) = 351 then 
             v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
               
             FUJ_IMP_COMPROBANTE_351(v_nro_operacion, v_cod_oficina, v_nro_caja);
             v_cod_respuesta := 'IMP';                                            
             
         elsif to_number(p_cod_tra_padre) = 352 then 
             v_tip_monto := 'O';
             lp_gen_transaccion;
            v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
                               
            FUJ_IMP_COMPROBANTE_352(v_fecha, v_hora, v_cod_usuario, v_cod_oficina);   
             v_cod_respuesta := 'IMP'; 
                                     
         elsif to_number(p_cod_tra_padre) = 353 then 
             v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
                
             FUJ_IMP_COMPROBANTE_353(v_nro_operacion, v_cod_oficina, v_nro_caja);

             v_cod_respuesta := 'IMP'; 
             
         elsif to_number(p_cod_tra_padre) in (360,361) then 
             ----Obtener datos adicionales para Transacción 360  
             Select nro_documento, referencia -- P.V. nro_documento2
               into v_nro_recibo, v_nro_factura
               from ge_movimientos
              where hora    = v_hora
                and nro_caja  = v_nro_caja --tuvo q haber pasado x caja
                and fecha     = v_fec_actual
                and rownum    = 1
                AND REVERSADO ='N';--reversadas no
                  
             v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||

             FUJ_IMP_TRANSACCION_360(v_cod_oficina , v_nro_operacion, v_nro_factura, 
                                    v_nro_caja, v_cod_moneda, v_nro_cuenta, v_fecha, v_hora);
                                    
                      

             v_cod_respuesta := 'IMP'; 
          elsif to_number(p_cod_tra_padre) = 139 then --- C.D.Fase 4
            v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
             fuj_imp_transaccion_139(v_cod_oficina, -- oficina
                                     v_nro_operacion,
                                     v_nro_caja, -- Caja
                                     v_cod_moneda, -- Moneda
                                     v_nro_cuenta, -- cuenta
                                     v_fecha,
                                     v_hora -- hora
                                      );  
            v_cod_respuesta := 'IMP';                                
          else
             v_cod_respuesta := '001'; -- para indicar que esta ok y se de imprimir
             v_msj_respuesta := 'Impresion de comprobante no previsto para la transacción...';
          end if;   
          ---Actualizar cantidad impresa
          lp_act_can_impresion;
       end if;
    end if;
 end if;
 /* armo finalmente el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 v_msj_respuesta;
 return(v_msj_salida);
exception
 when others then
     /* armo finalmente el mensaje de respuesta */
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm;
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_121;
/

