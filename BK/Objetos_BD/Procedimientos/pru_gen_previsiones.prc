CREATE OR REPLACE PROCEDURE IT.PRU_GEN_PREVISIONES
 IS
-- Modifica la tabla bienes con los datos de la prevision.
PROCEDURE LP_UPD_PREVISION
 (p_cod_bien number,
  p_mto_prevision number,
  p_fec_prevision date);
/* Proceso de previsiones: Consideraciones a tener en cuenta con el analisis:
- Son tomados los bienes que no fueron vendidos.
*/
   v_fec_actual     ge_calendarios.fec_actual%type;
   v_porcentaje     bu_plz_previsiones.por_prevision%type;
   v_prevision      bu_bienes.mto_prevision%type;
   v_diferencia     bu_bienes.mto_prevision%type;
   r_gmovi          ge_movimientos%rowtype;
   v_nro_secuencia  ge_movimientos.nro_secuencia%type;
   v_hora           ge_movimientos.hora%type;
   v_min_dias       bu_plz_previsiones.can_dias%type;
   v_cod_modulo     ba_modulos.cod_modulo%type := 26;
   v_cod_modalidad  ge_modalidades.cod_modalidad%type := 261;
   --- Cursor de bienes a calcular.
   cursor c_bienes is
    select b.cod_bien, b.seg_precio,
           b.val_contable, (v_fec_actual - b.fecha) can_dias,
           b.mto_prevision, b.cod_moneda, b.cod_oficina
      from bu_bienes b
     where estado = 'C'
       and (nvl(b.val_contable,0) <> nvl(b.seg_precio,0)
        or (v_fec_actual-fecha) >= v_min_dias );
   --- Cursor de cargos en suspenso a calcular.
   cursor c_cargos is
    select c.cod_bien, c.monto,
           (v_fec_actual - c.fecha) can_dias,
           c.mto_prevision, c.cod_moneda,
           b.cod_oficina, cod_modulo,
           cod_modalidad, cod_transaccion,
           c.fecha
      from bu_bienes b,
           bu_bie_cargos c
     where b.cod_bien = c.cod_bien
       and c.estado = 'S'
       and (v_fec_actual - c.fecha) >= v_min_dias;

-- Modifica la tabla bienes con los datos de la prevision.
PROCEDURE LP_UPD_PREVISION(p_cod_bien number,
                           p_mto_prevision number,
                           p_fec_prevision date)
 IS
BEGIN
   update bu_bienes
      set mto_prevision     = nvl(mto_prevision, 0) + p_mto_prevision,
          fec_ult_prevision = p_fec_prevision
    where cod_bien = p_cod_bien;
exception
   when others then
      raise_application_error(-20000,'Upd.Prev. '||sqlerrm);
END;
-- Modifica la tabla bienes con los datos de la prevision.
PROCEDURE LP_UPD_CAR_PREVISION(p_cod_bien        number,
                               p_cod_modulo      number,
                               p_cod_modalidad   number,
                               p_cod_transaccion number,
                               p_fecha           date,
                               p_mto_prevision   number,
                               p_fec_prevision   date)
 IS
BEGIN
   update bu_bie_cargos
      set mto_prevision = p_mto_prevision,
          fec_prevision = p_fec_prevision
    where cod_bien        = p_cod_bien
      and fecha           = p_fecha
      and cod_modulo      = p_cod_modulo
      and cod_modalidad   = p_cod_modalidad
      and cod_transaccion = p_cod_transaccion;
exception
   when others then
      raise_application_error(-20000,'Upd.Prev. '||sqlerrm);
END;
--- Inicio del Procedimiento ---
BEGIN
   v_fec_actual := pag_cal.fu_obt_fec_actual(v_cod_modulo);
   v_hora       := to_char(sysdate,'HH24:MI:SS');
   begin
     select min(p.can_dias)
       into v_min_dias
       from bu_plz_previsiones p;
   exception
     when others then
       raise_application_error(-20001,'Error al buscar Par?metros de Previsiones '||sqlerrm);
   end;
   v_nro_secuencia := 0;
   -- C?lculo de Previsiones sobre los Bienes.
   for reg in c_bienes loop
     begin
       select nvl(max(p.por_prevision),0)
         into v_porcentaje
         from bu_plz_previsiones p
        where reg.can_dias between p.can_dias and
                   nvl((select d.can_dias
                          from bu_plz_previsiones d
                         where d.cod_plazo = p.cod_plazo+1 ),999999);
     exception
       when others then
         raise_application_error(-20002,'Error al buscar el Porcentaje a Previsionar para el Bien '||sqlerrm);
     end;
     if v_porcentaje > 0 then
       v_prevision := round(nvl(reg.seg_precio,0)*(v_porcentaje/100),0);
     elsif nvl(reg.seg_precio,0) < nvl(reg.val_contable,0) then
       v_prevision := nvl(reg.val_contable,0) - nvl(reg.seg_precio,0);
       /*if nvl(v_prevision,0) < 0 then
         v_prevision := nvl(v_prevision,0) * -1;
       end if;*/
     else
       v_prevision := 0;
     end if;

     If v_prevision <> 0 and nvl(reg.mto_prevision,0) <> v_prevision then
       --- Inicializar datos cabecera del movimiento.
       r_gmovi.cod_usuario    := user;
       r_gmovi.hora           := v_hora;
       r_gmovi.fecha          := v_fec_actual;
       r_gmovi.fec_valor      := v_fec_actual;
       r_gmovi.cod_mod_padre  := v_cod_modulo;
       r_gmovi.cod_mad_padre  := v_cod_modalidad;
       r_gmovi.cod_modulo     := v_cod_modulo;
       r_gmovi.cod_modalidad  := v_cod_modalidad;
       r_gmovi.cod_oficina    := reg.cod_oficina;
       r_gmovi.cod_ofi_origen := reg.cod_oficina;
       r_gmovi.cod_moneda     := reg.cod_moneda;
       r_gmovi.estado         := 'N';
       r_gmovi.reversado      := 'N';
       r_gmovi.emi_aviso      := 'N';
       r_gmovi.protegido      := 'N';
       if v_nro_secuencia + 2 > 999 then
         v_nro_secuencia := 0;
         v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
         r_gmovi.hora    := v_hora;
       end if;
        v_diferencia  := nvl(v_prevision,0) - nvl(reg.mto_prevision,0);
        r_gmovi.monto := nvl(v_diferencia,0);
        if v_diferencia <> 0 then
          if nvl(v_diferencia,0) < 0 then
             v_diferencia := nvl(v_diferencia*-1,0);
             --- Desafectar previsiones.
             v_nro_secuencia         := v_nro_secuencia + 1;
             r_gmovi.monto           := nvl(v_diferencia*-1,0);
             r_gmovi.nro_secuencia   := v_nro_secuencia;
             r_gmovi.cod_tra_padre   := 731;
             r_gmovi.cod_transaccion := 731;
             r_gmovi.concepto        := 'EXTORNO DE PREVISIONES';
             pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
          elsif nvl(v_diferencia,0) > 0 then
             --- Constituir previsiones.
             v_nro_secuencia         := v_nro_secuencia + 1;
             r_gmovi.nro_secuencia   := v_nro_secuencia;
             r_gmovi.cod_tra_padre   := 730;
             r_gmovi.cod_transaccion := 730;
             r_gmovi.concepto        := 'PREVISIONES DEL MES';
             pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
          end if;
          -- Actualiza los Bienes insert?ndole la fecha y la previsi?n.
          lp_upd_prevision(reg.cod_bien,v_diferencia,v_fec_actual);
        end if;
     end if;
   end loop;
   -- C?lculo de las previsiones sobre los Cargos en suspenso.
   v_prevision  := 0;
   v_porcentaje := 0;
   v_diferencia := 0;
   -- v_nro_secuencia continua de las previsiones de los bienes.
   for c in c_cargos loop
     begin
       select nvl(max(p.por_prevision),0)
         into v_porcentaje
         from bu_plz_previsiones p
        where c.can_dias between p.can_dias and
                   nvl((select d.can_dias
                          from bu_plz_previsiones d
                         where d.cod_plazo = p.cod_plazo+1 ),999999);
     exception
       when others then
         raise_application_error(-20002,'Error al buscar el Porcentaje a Previsionar para el Cargo '||sqlerrm);
     end;
     if v_porcentaje > 0 then
       v_prevision := round(nvl(c.monto,0)*(v_porcentaje/100),0);
     else
       v_prevision := 0;
     end if;
     If v_prevision <> 0 and nvl(c.mto_prevision,0) <> v_prevision then
       --- Inicializar datos cabecera del movimiento.
       r_gmovi.cod_usuario    := user;
       r_gmovi.hora           := v_hora;
       r_gmovi.fecha          := v_fec_actual;
       r_gmovi.fec_valor      := v_fec_actual;
       r_gmovi.cod_mod_padre  := v_cod_modulo;
       r_gmovi.cod_mad_padre  := v_cod_modalidad;
       r_gmovi.cod_modulo     := v_cod_modulo;
       r_gmovi.cod_modalidad  := v_cod_modalidad;
       r_gmovi.cod_oficina    := c.cod_oficina;
       r_gmovi.cod_ofi_origen := c.cod_oficina;
       r_gmovi.cod_moneda     := c.cod_moneda;
       r_gmovi.estado         := 'N';
       r_gmovi.reversado      := 'N';
       r_gmovi.emi_aviso      := 'N';
       r_gmovi.protegido      := 'N';
       if v_nro_secuencia + 2 > 999 then
         v_nro_secuencia := 0;
         v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
         r_gmovi.hora    := v_hora;
       end if;
       v_diferencia  := nvl(v_prevision,0) - nvl(c.mto_prevision,0);
       r_gmovi.monto := nvl(v_diferencia,0);
       if v_diferencia <> 0 then
         if nvl(v_diferencia,0) < 0 then
           v_diferencia := nvl(v_diferencia*-1,0);
           --- Desafectar previsiones.
           v_nro_secuencia         := v_nro_secuencia + 1;
           r_gmovi.monto           := nvl(v_diferencia*-1,0);
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           r_gmovi.cod_tra_padre   := 731;
           r_gmovi.cod_transaccion := 731;
           r_gmovi.concepto        := 'EXTORNO DE PREVISIONES';
           pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
         elsif nvl(v_diferencia,0) > 0 then
           --- Constituir previsiones.
           v_nro_secuencia         := v_nro_secuencia + 1;
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           r_gmovi.cod_tra_padre   := 730;
           r_gmovi.cod_transaccion := 730;
           r_gmovi.concepto        := 'PREVISIONES DEL MES';
           pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
         end if;
         -- Actualiza los cargo insert?ndole la fecha y monto de la previsi?n.
         lp_upd_car_prevision(c.cod_bien,
                              c.cod_modulo,
                              c.cod_modalidad,
                              c.cod_transaccion,
                              c.fecha,
                              v_diferencia,
                              v_fec_actual);
       end if;
     end if;
   end loop;
END;
/

