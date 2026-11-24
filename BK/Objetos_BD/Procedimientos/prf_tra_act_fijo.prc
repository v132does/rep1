CREATE OR REPLACE PROCEDURE IT.prf_tra_act_fijo
(
   p_cod_bien     af_bienes.cod_bien%TYPE,
   p_fec_baja     af_bienes.fec_enajenacion%TYPE,
   p_ofi_destino  af_bienes.cod_oficina%TYPE,
   p_area_destino af_bienes.cod_area%TYPE
) IS
   -- Datos para generar el movimiento
   v_fec_actual    DATE := pag_cal.fu_obt_fec_actual(13); -- fecha de hoy
   v_hor_actual    VARCHAR2(08) := to_char(SYSDATE, 'HH24:MI:SS'); -- Hora actual
   v_cod_usuario   VARCHAR2(10) := upper(USER); -- usuario
   v_nro_secuencia NUMBER(3) := 0; -- secuencia del mov.
   r_bien          af_bienes%ROWTYPE;
   r_articulo      af_articulos%ROWTYPE;
   r_gmovi         ge_movimientos%ROWTYPE;
   r_tip_transfer  af_tip_movimientos%ROWTYPE;
   r_suministro    in_suministros%ROWTYPE;
   --
BEGIN
   v_hor_actual := pag_gen.fu_obt_sig_segundo(v_hor_actual);

   IF nvl(p_cod_bien, 0) = 0 THEN
      raise_application_error(-20000, 'Error al obtener el codigo del bien');
   END IF;

   IF p_fec_baja IS NULL THEN
      raise_application_error(-20000, 'Debe ingresar la fecha de baja');
   END IF;

   IF nvl(p_ofi_destino, 0) = 0 THEN
      raise_application_error(-20000, 'Debe ingresar la oficina de destino');
   END IF;

   IF nvl(p_area_destino, 0) = 0 THEN
      raise_application_error(-20000, 'Debe ingresar el area de destino');
   END IF;

   prf_obt_bien(p_cod_bien, r_bien);
   prf_obt_articulo(r_bien.cod_articulo, r_articulo);

   IF nvl(r_articulo.ind_suministro, 'N') = 'S' THEN
      prz_obt_suministro(p_cod_bien, r_suministro);
      IF r_suministro.estado = 'A' THEN
         prf_act_articulos(r_articulo.cod_articulo);
      END IF;
   END IF;

   IF r_bien.cod_oficina = p_ofi_destino AND fug_obt_tip_implementacion = 2 THEN
      NULL;
   ELSE
      /*************************************************************************/
      --- MOVIMIENTOS OFICINA DE ORIGEN ---
      --- DEPRECIACION
      /*************************************************************************/
      IF nvl(r_bien.dep_acumulada, 0) != 0 THEN
         v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
         -- Genero el movimiento
         r_gmovi.cod_modulo      := r_articulo.cod_modulo;
         r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
         r_gmovi.cod_oficina     := r_bien.cod_oficina;
         r_gmovi.nro_cuenta      := NULL;
         r_gmovi.cod_moneda      := r_bien.cod_moneda;
         r_gmovi.cod_usuario     := v_cod_usuario;
         r_gmovi.hora            := v_hor_actual;
         r_gmovi.fecha           := v_fec_actual;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         r_gmovi.fec_valor       := v_fec_actual;
         r_gmovi.cod_tra_padre   := 1300;
         r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
         r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
         r_gmovi.cod_transaccion := r_articulo.cod_tra_dep_baja;
         r_gmovi.monto           := r_bien.dep_acumulada;
         r_gmovi.nro_documento   := r_bien.cod_bien;
         r_gmovi.cod_tasa        := NULL;
         r_gmovi.val_tasa        := NULL;
         r_gmovi.cotizacion      := NULL;
         r_gmovi.cod_ofi_origen  := r_bien.cod_oficina;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := substr(r_bien.descripcion, 1, 35);
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.nro_caja        := NULL;
         r_gmovi.cod_rubro       := NULL;
         r_gmovi.tip_mov_rubro   := 'C'; --CREDITO
         pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N'); -- no es nocturno
      END IF;
      /*************************************************************************/
      --- REVALUO
      /*************************************************************************/
      v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
      -- Genero el movimiento
      r_gmovi.cod_modulo      := r_articulo.cod_modulo;
      r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
      r_gmovi.cod_oficina     := r_bien.cod_oficina;
      r_gmovi.nro_cuenta      := NULL;
      r_gmovi.cod_moneda      := r_bien.cod_moneda;
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hor_actual;
      r_gmovi.fecha           := v_fec_actual;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.fec_valor       := v_fec_actual;
      r_gmovi.cod_tra_padre   := 1300;
      r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
      r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
      r_gmovi.cod_transaccion := r_articulo.cod_tra_rev_baja;
      r_gmovi.monto           := r_bien.rev_actual;
      r_gmovi.nro_documento   := r_bien.cod_bien;
      r_gmovi.cod_tasa        := NULL;
      r_gmovi.val_tasa        := NULL;
      r_gmovi.cotizacion      := NULL;
      r_gmovi.cod_ofi_origen  := r_bien.cod_oficina;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := substr(r_bien.descripcion, 1, 35);
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.nro_caja        := NULL;
      r_gmovi.cod_rubro       := NULL;
      r_gmovi.tip_mov_rubro   := 'C'; --CREDITO
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N'); -- no es nocturno
      /*************************************************************************/
      --- MOVIMIENTOS OFICINA DE DESTINO
      --- DEPRECIACION
      /*************************************************************************/
      IF nvl(r_bien.dep_acumulada, 0) != 0 THEN
         v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
         -- Genero el movimiento
         r_gmovi.cod_modulo      := r_articulo.cod_modulo;
         r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
         r_gmovi.cod_oficina     := p_ofi_destino;
         r_gmovi.nro_cuenta      := NULL;
         r_gmovi.cod_moneda      := r_bien.cod_moneda;
         r_gmovi.cod_usuario     := v_cod_usuario;
         r_gmovi.hora            := v_hor_actual;
         r_gmovi.fecha           := v_fec_actual;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         r_gmovi.fec_valor       := v_fec_actual;
         r_gmovi.cod_tra_padre   := 1300;
         r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
         r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
         r_gmovi.cod_transaccion := r_articulo.cod_tra_dep_baja;
         r_gmovi.monto           := (r_bien.dep_acumulada * -1);
         r_gmovi.nro_documento   := r_bien.cod_bien;
         r_gmovi.cod_tasa        := NULL;
         r_gmovi.val_tasa        := NULL;
         r_gmovi.cotizacion      := NULL;
         r_gmovi.cod_ofi_origen  := r_bien.cod_oficina;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := r_bien.descripcion;
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.nro_caja        := NULL;
         r_gmovi.cod_rubro       := NULL;
         r_gmovi.tip_mov_rubro   := 'D'; --DEBITO
         pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N'); -- no es nocturno
      END IF;
      /*************************************************************************/
      --- REVALUO
      /*************************************************************************/
      v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
      -- Genero el movimiento
      r_gmovi.cod_modulo      := r_articulo.cod_modulo;
      r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
      r_gmovi.cod_oficina     := p_ofi_destino;
      r_gmovi.nro_cuenta      := NULL;
      r_gmovi.cod_moneda      := r_bien.cod_moneda;
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hor_actual;
      r_gmovi.fecha           := v_fec_actual;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.fec_valor       := v_fec_actual;
      r_gmovi.cod_tra_padre   := 1300;
      r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
      r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
      r_gmovi.cod_transaccion := r_articulo.cod_tra_rev_baja;
      r_gmovi.monto           := (r_bien.rev_actual * -1);
      r_gmovi.nro_documento   := r_bien.cod_bien;
      r_gmovi.cod_tasa        := NULL;
      r_gmovi.val_tasa        := NULL;
      r_gmovi.cotizacion      := NULL;
      r_gmovi.cod_ofi_origen  := r_bien.cod_oficina;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := r_bien.descripcion;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.nro_caja        := NULL;
      r_gmovi.cod_rubro       := NULL;
      r_gmovi.tip_mov_rubro   := 'D'; --DEBITO
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N'); -- no es nocturno
   END IF;
   --- Actualizo el bien
   UPDATE af_bienes
      SET fec_enajenacion = p_fec_baja,
          cod_oficina     = p_ofi_destino,
          cod_area        = p_area_destino
    WHERE cod_bien = p_cod_bien;
   IF SQL%NOTFOUND THEN
      raise_application_error(-20000, 'El bien no fue actualizado');
   END IF;
   --- Actualizo el suministro
   IF nvl(r_articulo.ind_suministro, 'N') = 'S' THEN
      UPDATE in_suministros
         SET cod_oficina = p_ofi_destino,
             cod_area    = p_area_destino,
             estado      = 'T'
       WHERE cod_suministro = p_cod_bien;
      IF SQL%NOTFOUND THEN
         raise_application_error(-20000, 'El suministro no fue actualizado');
      END IF;
   END IF;
END;
/

