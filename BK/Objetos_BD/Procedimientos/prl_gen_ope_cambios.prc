CREATE OR REPLACE PROCEDURE IT.PRL_GEN_OPE_CAMBIOS
 /* procedimiento para generar la operacion de cambios respectiva  cuando la operacion generada involucra cambios */
 (p_cod_usuario       in varchar2 default null) is
--
v_fec_actual          date := pag_cal.fu_obt_fec_actual(7); --fecha de hoy
v_cod_modalidad       NUMBER(04);
v_cod_tip_ope_bcp     lc_tip_operaciones.cod_tip_ope_bcp%type;
r_gmovi               ge_movimientos%rowtype;
v_cod_persona         ba_personas.cod_persona%type;
v_cod_mon_local       varchar2(4) := pag_gen.FU_OBT_MON_LOCAL;
v_cod_tip_operacion   number(4);
--
CURSOR CUR_DATOS IS
    SELECT A.HORA, A.COD_MODALIDAD, A.COD_MONEDA, A.MONTO, A.MTO_EQU_LOCAL, A.COTIZACION, A.COD_OFI_ORIGEN, A.COD_OFICINA,
           PAL_CAM.FU_OBT_OFI_CAMBIO(A.cod_ofi_origen) COD_OFI_CAMBIO, A.ROWID FILA, A.NRO_DOCUMENTO, A.NRO_CUENTA,
           B.TIPO, NRO_SECUENCIA, A.COD_USUARIO
      FROM GE_TRANSACCIONES B, GE_MOVIMIENTOS A
     WHERE ((A.cod_usuario = p_cod_usuario) or (p_cod_usuario is null and a.cod_usuario in ('WEB','TAS')))
       AND A.COD_MONEDA <> v_cod_mon_local
       AND A.monto > 0
       AND A.COD_MODULO = B.COD_MODULO
       AND A.COD_MODALIDAD = B.COD_MODALIDAD
       AND A.COD_TRANSACCION = B.COD_TRANSACCION
       AND B.TIPO IN ('D','C')
       AND B.RUTINA1 IS NOT NULL
       AND B.BATCH = 'B'
       AND A.COD_BCO_CENTRAL IS NULL
       AND A.COD_MOD_PADRE <> 7
       AND A.COD_TRANSACCION <> 760
       AND EXISTS (SELECT 0
                     FROM GE_TRANSACCIONES E, GE_MOVIMIENTOS D
                    WHERE D.COD_USUARIO = A.COD_USUARIO
                      AND D.HORA = A.HORA
                      AND D.FECHA = A.FECHA
                      AND D.COD_MONEDA = V_COD_MON_LOCAL
                      AND D.MONTO > 0
                      AND E.COD_MODULO = D.COD_MODULO
                      AND E.COD_MODALIDAD = D.COD_MODALIDAD
                      AND E.COD_TRANSACCION = D.COD_TRANSACCION
                      AND E.TIPO IN ('D','C')
                      AND E.TIPO <> B.TIPO
                    );
/*Función local q retorna la persona relacionada a la entidad*/
FUNCTION LF_OBT_PER_ENTIDAD
return varchar2
 IS
v_cod_persona ge_par_generales.cod_persona%type;
BEGIN
   select cod_persona
   into v_cod_persona
   from ge_par_generales;
   return v_cod_persona;
exception
   when no_data_found then
     raise_application_error(-20000,
     'Parámetro general no registrado');
   when too_many_rows then
     raise_application_error(-20000,
     'Parámetro general duplicado');
end;
---
BEGIN
   FOR mv in CUR_DATOS LOOP
     if mv.tipo = 'D' then
        -- compra
        v_cod_tip_operacion := 16;
     else
        v_cod_tip_operacion := 30;
     end if;
     -- obtengo los datos del tipo de operacion
     select cod_tip_ope_bcp,cod_modalidad
       into v_cod_tip_ope_bcp, v_cod_modalidad
       from lc_tip_operaciones
      where cod_tip_operacion = v_cod_tip_operacion;
      begin
       -- Busco la persona
       select cod_persona
         into v_cod_persona
         from ge_cta_clientes
        where nro_cuenta =  mv.nro_cuenta
          and relacion = 'P';
      exception
        when no_data_found then
             v_cod_persona := LF_OBT_PER_ENTIDAD;
      end;
      -- no es operacion de cambios, entonces se cambia todos los registros
      update ge_movimientos
          set cod_mod_padre = 7,
              cod_mad_padre = v_cod_modalidad,
              cod_tip_ope_cambio = decode(nro_secuencia,mv.nro_secuencia,v_cod_tip_operacion,
                                   decode(v_cod_modalidad,71,3,8)),
              cod_bco_central = v_cod_tip_ope_bcp,
              nro_secuencia = decode(nro_secuencia,mv.nro_secuencia,1,decode(nro_secuencia,1,nro_secuencia+3,nro_secuencia))
        where cod_usuario = mv.cod_usuario
          and hora  = mv.hora;
      --- genera movimiento x persona, para listados ---
      r_gmovi.cod_usuario   := mv.cod_usuario;
      r_gmovi.hora          := mv.hora;
      r_gmovi.nro_secuencia := 9; -- FIJO para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := 70;
      r_gmovi.cod_oficina   := mv.cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := mv.cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 901;
      r_gmovi.cod_transaccion := 760;
      r_gmovi.nro_documento := mv.nro_documento;
      r_gmovi.nro_documento2 := v_cod_persona;
      r_gmovi.monto         := 0;
      r_gmovi.estado        := 'N';
      r_gmovi.cod_ofi_origen := mv.cod_ofi_origen;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := v_cod_modalidad;
      r_gmovi.concepto      := 'Operacion Automatica de Cambios';
      r_gmovi.cotizacion    := null;
      r_gmovi.mto_equ_local := null;
      r_gmovi.cod_tip_ope_cambio := null;
      r_gmovi.COD_BCO_CENTRAL    := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      if v_cod_tip_operacion = 16 then --16-Compra Debito en Cta ME--
         --actualizar posición
         UPDATE LC_POSICIONES SET
                MTO_COM_NEF_ACT = NVL(MTO_COM_NEF_ACT,0) + mv.monto,
                MTO_COM_NEF_LOC = NVL(MTO_COM_NEF_LOC,0) + mv.mto_equ_local
          WHERE COD_OFI_CAMBIO = mv.cod_ofi_cambio
            AND COD_MONEDA = mv.cod_moneda
            AND COD_TIP_OPE_BCP = v_cod_tip_ope_bcp;
         --insertar posición si no existe
         IF SQL%NOTFOUND THEN
            INSERT INTO LC_POSICIONES
                (COD_MONEDA,COD_TIP_OPE_BCP,COD_OFI_CAMBIO,
                 MTO_COM_NEF_ACT,MTO_COM_NEF_LOC)
            VALUES
                (mv.cod_moneda, v_cod_tip_ope_bcp,mv.cod_ofi_cambio,
                 mv.monto,mv.mto_equ_local);
         END IF;
      else --30-Venta Credito en Cta ME--
         UPDATE LC_POSICIONES SET
                MTO_VTA_NEF_ACT = NVL(MTO_VTA_NEF_ACT,0) + mv.monto,
                MTO_VTA_NEF_LOC = NVL(MTO_VTA_NEF_LOC,0) + mv.mto_equ_local
          WHERE COD_OFI_CAMBIO = mv.cod_ofi_cambio
            AND COD_MONEDA = mv.cod_moneda
            AND COD_TIP_OPE_BCP = v_cod_tip_ope_bcp;
         --insertar posición si no existe
         IF SQL%NOTFOUND THEN
            INSERT INTO LC_POSICIONES
                (COD_MONEDA,COD_TIP_OPE_BCP,COD_OFI_CAMBIO,
                 MTO_VTA_NEF_ACT,MTO_VTA_NEF_LOC)
            VALUES
                (mv.cod_moneda, v_cod_tip_ope_bcp,mv.cod_ofi_cambio,
                 mv.monto,mv.mto_equ_local);
         END IF;
      end if;
   END LOOP;
END;
/

