CREATE OR REPLACE PROCEDURE IT.PRA_VER_INI_CIERRE
 IS
v_cantidad number;
v_fecha    date := PAG_CAL.FU_OBT_FEC_ACTUAL(7);
v_error varchar2(4000) := '';
v_existe varchar2(1);
v_dir_correo varchar2(500);
v_db_name    varchar2(100);
procedure lp_car_msj_error(p_msj_error in varchar2) is
begin
  if v_error is null then
    v_error := p_msj_error;
  else
    v_error := substr(v_error || chr(10) || p_msj_error,1,4000);
  end if;
end;
BEGIN
   SELECT COUNT(*)
     INTO v_cantidad
     FROM GE_MOVIMIENTOS
    WHERE ESTADO IN ('J')  -- Pendiente de pasar por Caja
      AND REVERSADO = 'N'; -- No reversado
   if nvl(v_cantidad,0) > 0 then
      lp_car_msj_error('Existen Movimientos Pendientes de pasar por Caja');
   end if;
   SELECT COUNT(*)
     INTO V_CANTIDAD
     FROM GE_MOVIMIENTOS G
    WHERE G.ESTADO IN ('X')  -- PENDIENTES DE AUTORIZACION
      AND G.REVERSADO = 'N'
      -- No debe verificar los movimientos de detalle de cheque C/N/B.
      -- con autorización pendiente por sobregiro. 07/2015 V.V.
      AND  G.COD_TRA_PADRE  not in (355, 345); --se incluye Tran.Padre 345 de cheques ingresados en BT 
   if nvl(v_cantidad,0) > 0 then
      lp_car_msj_error('Existen Movimientos Pendientes de Autorización');
   end if;
   -- Control de verificacion por la carga de la cotización.
   SELECT COUNT(*)
     INTO v_cantidad
     FROM ge_cotizaciones c
    WHERE c.FECHA = v_fecha;
   if nvl(v_cantidad,0) <= 0 then
      lp_car_msj_error('Hoy No se realizó la carga de la cotización de la cambios');
   end if;
   --
   -- Control de cliente principal
   declare
      cursor c_mov is
      select distinct nro_cuenta, cod_modulo, cod_modalidad, cod_oficina
        from ge_movimientos
       where nro_cuenta is not null;
   begin
      for reg in c_mov loop
        begin
          select 'S'
            into v_existe
            from ge_cta_clientes gcc,
                 ge_clientes     gc
           where gcc.nro_cuenta = reg.nro_cuenta
             and gcc.relacion = 'P'
             and gcc.cod_persona = gc.cod_persona
             and gcc.cod_modulo = reg.cod_modulo
             and gcc.cod_modalidad = reg.cod_modalidad;
        exception
          when no_data_found then
            lp_car_msj_error('Cta.sin Cliente Principal : ' || reg.nro_cuenta ||
                             ' Mod. '   || reg.cod_modulo ||
                             ' Modal. ' || reg.cod_modalidad ||
                             ' Ofi. '   || reg.cod_oficina);
         when too_many_rows then
            lp_car_msj_error('Cta.con Clie.Princ. duplicado: ' || reg.nro_cuenta ||
                             ' Mod. '   || reg.cod_modulo ||
                             ' Modal. ' || reg.cod_modalidad ||
                             ' Ofi. '   || reg.cod_oficina);
        end;
      end loop;
   end;   
   -- Se verifica si la rutina 1 definida en la transaccion existe como procedimiento almacenado
   declare
      cursor c_mov is
      select distinct m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.cod_oficina, t.rutina1
        from ge_movimientos   m,
             ge_transacciones t
       where not exists (select 1
                           from all_procedures
                          where owner = 'IT'
                            and object_name = t.rutina1)
         and t.rutina1 is not null
         and m.cod_modulo = t.cod_modulo
         and m.cod_modalidad = t.cod_modalidad
         and m.cod_transaccion = t.cod_transaccion
         and m.nro_cuenta is not null;
   begin
      for reg in c_mov loop
        lp_car_msj_error('No existe la rutina para la transaccion : ' || reg.cod_transaccion ||
                         ' Mod. '   || reg.cod_modulo ||
                         ' Modal. ' || reg.cod_modalidad ||
                         ' Rutina1 ' || reg.rutina1);
      end loop;
   end; 
   --
   -- Control de movimientos sin oficina
   declare
      cursor c_mov is
      select m.fecha, m.hora, m.cod_usuario, m.nro_secuencia
        from ge_movimientos   m,
             ge_transacciones t
       where m.cod_modulo = t.cod_modulo(+)
         and m.cod_modalidad = t.cod_modalidad(+)
         and m.cod_transaccion = t.cod_transaccion(+)
         and m.cod_oficina is null
         and (exists (select 1
                        from ge_tip_asientos a
                       where a.cod_tip_asiento = t.cod_tip_asiento) or
              exists (select 1
                        from ge_tip_asientos a
                       where a.cod_tip_asiento = t.cod_tip_asiento2) or
              m.cod_rubro is not null);
   begin
      for reg in c_mov loop
        lp_car_msj_error('Movimiento sin oficina :' ||
                         ' Fecha. ' || reg.fecha ||
                         ' Hora. '  || reg.hora ||
                         ' Usu. '   || reg.cod_usuario ||
                         ' Sec. '   || reg.nro_secuencia);
      end loop;
   end;   
   -- Control de movimientos cod rubro contable inconrrecto
   declare
      cursor c_mov is
      select m.fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.cod_rubro, m.cod_moneda
        from ge_movimientos   m
       where cod_rubro is not null 
         and not exists (select 0 
                           from cb_rubros b
                          where b.cod_rubro = m.cod_rubro
                            and b.cod_moneda = m.cod_moneda);
   begin
      for reg in c_mov loop
        lp_car_msj_error('Movimiento con Rubro invalido :' ||
                         ' Fecha. ' || reg.fecha ||
                         ' Hora. '  || reg.hora ||
                         ' Usu. '   || reg.cod_usuario ||
                         ' Sec. '   || reg.nro_secuencia||
                         ' Rubro '  || reg.cod_rubro);
      end loop;
   end; 
   -- control de la posicion de cambios // ya no hace falta, sólo en etapa de implementación, esto ya se ajusta en el cierre de cambios
/*   declare
      cursor c_mov is
          select t.*, nvl(mto_pos,0) - nvl(mto_mov,0) dif_monto
          from
          (
          select a.cod_moneda,
                 o.cod_ofi_cambio ofi_cambios,
                 c.descripcion des_ofi_cambios,
                 b.afe_posicion afe_pos, decode(b.afe_posicion,'E','Efectivo','O','Otros','N','No Afecta') des_afe_pos,
                 a.cod_bco_central cod_bcp,
                 a.cod_mad_padre, d.descripcion des_modal,
                 b.cod_mad_hijo tipo,
                 decode(a.cod_mad_padre,71,decode(b.afe_posicion,'E',xx_mto_com_efe_act,'O',xx_mto_com_nef_act,0),
                                        72,decode(b.afe_posicion,'E',xx_mto_vta_efe_act,'O',xx_mto_vta_nef_act,0), 
                                        73,decode(b.cod_mad_hijo,71,decode(b.afe_posicion,'E',xx_mto_arb_com_efe_act,'O',xx_mto_arb_com_nef_act,0),
                                                                 72,decode(b.afe_posicion,'E',xx_mto_arb_vta_efe_act,'O',xx_mto_arb_vta_nef_act,0),0),                              
                                        74,decode(b.cod_mad_hijo,71,decode(b.afe_posicion,'E',xx_mto_cje_com_efe_act,'O',xx_mto_cje_com_nef_act,0),
                                                                 72,decode(b.afe_posicion,'E',xx_mto_cje_vta_efe_act,'O',xx_mto_cje_vta_nef_act,0),0),0) mto_pos,                              
                                        
                                        
                 sum(nvl(a.monto,0)) mto_mov
          from ba_oficinas o, lc_tip_operaciones b, ge_movimientos a, ba_oficinas c,
               ge_modalidades d,
          (
          SELECT
          cod_moneda xx_cod_moneda,
          cod_tip_ope_bcp xx_cod_tip_ope_bcp,
          cod_ofi_cambio xx_cod_ofi_cambio,

          mto_com_efe_act xx_mto_com_efe_act,
          mto_com_nef_act xx_mto_com_nef_act,
          mto_vta_efe_act xx_mto_vta_efe_act,
          mto_vta_nef_act xx_mto_vta_nef_act,

          mto_arb_com_efe_act xx_mto_arb_com_efe_act,
          mto_arb_com_nef_act xx_mto_arb_com_nef_act,
          mto_arb_vta_efe_act xx_mto_arb_vta_efe_act,
          mto_arb_vta_nef_act xx_mto_arb_vta_nef_act,

          mto_cje_com_efe_act xx_mto_cje_com_efe_act,
          mto_cje_com_nef_act xx_mto_cje_com_nef_act,
          mto_cje_vta_efe_act xx_mto_cje_vta_efe_act,
          mto_cje_vta_nef_act xx_mto_cje_vta_nef_act,

          mto_com_efe_loc xx_mto_com_efe_loc,
          mto_com_nef_loc xx_mto_com_nef_loc,
          mto_vta_efe_loc xx_mto_vta_efe_loc,
          mto_vta_nef_loc xx_mto_vta_nef_loc
          from lc_posiciones
          )
          where a.cod_tip_ope_cambio = b.cod_tip_operacion
          and b.afe_posicion in ('E','O')
          and a.cod_ofi_origen = o.cod_oficina
          and a.estado = 'N'
          and a.reversado = 'N'
          and c.cod_oficina = o.cod_ofi_cambio
          and d.cod_modulo = 7
          and d.cod_modalidad = a.cod_mad_padre
          and xx_cod_moneda = a.cod_moneda
          and xx_cod_tip_ope_bcp = a.cod_bco_central
          and xx_cod_ofi_cambio = o.cod_ofi_cambio
          group by a.cod_moneda,
                   o.cod_ofi_cambio, c.descripcion,
                   b.afe_posicion, a.cod_bco_central,
                   a.cod_mad_padre, d.descripcion,
                   b.cod_mad_hijo,
                   decode(a.cod_mad_padre,71,decode(b.afe_posicion,'E',xx_mto_com_efe_act,'O',xx_mto_com_nef_act,0),
                                          72,decode(b.afe_posicion,'E',xx_mto_vta_efe_act,'O',xx_mto_vta_nef_act,0), 
                                          73,decode(b.cod_mad_hijo,71,decode(b.afe_posicion,'E',xx_mto_arb_com_efe_act,'O',xx_mto_arb_com_nef_act,0),
                                                                 72,decode(b.afe_posicion,'E',xx_mto_arb_vta_efe_act,'O',xx_mto_arb_vta_nef_act,0),0),                              
                                          74,decode(b.cod_mad_hijo,71,decode(b.afe_posicion,'E',xx_mto_cje_com_efe_act,'O',xx_mto_cje_com_nef_act,0),
                                                                 72,decode(b.afe_posicion,'E',xx_mto_cje_vta_efe_act,'O',xx_mto_cje_vta_nef_act,0),0),0)                              
          ) t
          where nvl(mto_pos,0) <> nvl(mto_mov,0);
   begin
      for reg in c_mov loop
        lp_car_msj_error('Posicion de Cambios: Suma de Mov. ' ||
                         reg.cod_moneda||' '||reg.mto_mov||' y Pos. '||reg.mto_pos||' no coinciden para '||
                         ' Ofic.: ' || reg.ofi_cambios ||
                         ' Mon.: '  || reg.cod_moneda ||
                         ' Cod.Bcp. '  || reg.cod_bcp ||
                         ' . Ejecutar: PRL_AJU_DIF_MOV_POSICION.');
      end loop;
   end;    
*/


   -- SI HAY MENSAJES DE ERROR
   if v_error is not null then
      -- Obtiene la direccion de correo del operador
      begin
        select u.dir_correo
          into v_dir_correo
          from ba_usuarios u
         where u.cod_usuario = user;
      exception
        when others then
          raise_application_error(-20000, 'Problema al obtener la direccion de correo del operador');
      end;
      -- Obtiene el nombre de la base de datos
      select UPPER(SYS_CONTEXT('USERENV', 'DB_NAME'))
        into v_db_name
        from dual;
      -- Envia el mail
      /*it_mail.mail (fug_obt_dir_correo,
                    v_dir_correo,
                    'Problemas en el Cierre - BD: ' || v_db_name,
                    v_error);*/
      raise_application_error(-20000, v_error||chr(10)||' Detalles en su correo ');
   end if;  
   
   
   
     
END;
/

