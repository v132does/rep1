CREATE OR REPLACE PROCEDURE IT.PRT_CAM_CATEGORIA(p_nro_cuenta
IN pr_cta_prestamos.nro_cuenta%type default null)
 IS

  v_fec_actual          ge_calendarios.fec_actual%type  := pae_cnf.fu_obt_fec_actual(5);
  v_mon_local  constant ge_cuentas.cod_moneda%type      := pag_gen.fu_obt_mon_local;
  v_cod_tra_hij         ge_movimientos.cod_transaccion%type;
  v_concepto            ge_movimientos.concepto%type;
  r_mvto                ge_movimientos%rowtype;
  v_redondeo            number(5);
  v_est_cuenta          varchar2(1);
  v_fecha_ant           date;
  v_can_user            number;
   -- Variables para manejo de usuarios --
  v_usuario         ba_usuarios.cod_usuario%type;
  TYPE typ_usu_secuencia IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
  v_usu_secuencia   typ_usu_secuencia;  
  
  TYPE t_usu_hor IS TABLE OF VARCHAR2(8) INDEX BY VARCHAR2(15);
  v_usu_hora t_usu_hor;

  --->Cursor de tarjetas
  cursor cuentas is
    select t.nro_cuenta,
           nvl(t.cod_modulo, 5) cod_modulo,
           t.cod_modalidad,
           t.cod_oficina,
           t.cod_moneda,
           t.sal_facturar + t.sal_facturado + t.sal_financiado + t.sal_cuo_pendientes sal_tarjeta,
           t.cat_automatica  new_categoria,
           pag_gen.fu_obt_cotizacion(t.cod_moneda, v_fec_actual) cotizacion
    from ta_cta_tarjetas t, ge_est_cuentas e
   where nro_cuenta      = nvl(p_nro_cuenta, nro_cuenta)
     and t.cod_modulo    = e.cod_modulo
     and t.cod_modalidad = e.cod_modalidad
     and t.estado        = e.estado
     and e.activo        = 'S'
     and nvl(t.cat_automatica,0) >1
     and not exists (select 1 from ov_cta_vencidas ov
                      where ov.nro_cta_origen = t.nro_cuenta);

  cursor movimientos is
    select  monto, nro_cuenta, cod_moneda, cod_oficina, est_cuenta, estado, cod_ofi_origen,
    concepto, cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion, cod_modulo, cod_modalidad,
    mto_equ_local, cotizacion
      from ta_movimientos_his a---cambiar a ta_movimientos
     where a.referencia   = 'RECLAS.TARJETA'
       and nro_cuenta     = nvl(p_nro_cuenta, nro_cuenta)
       and a.fecha        = v_fecha_ant
       and not exists (select 1 from ov_cta_vencidas ov
                        where ov.nro_cta_origen = a.nro_cuenta);

begin
  begin
    DBMS_OUTPUT.ENABLE(1000000);
  end;
 -- Verifica la cantidad de usuarios disponibles 
   BEGIN
     SELECT COUNT(*)
       INTO v_can_user
       FROM ba_cod_referencias
       WHERE dominio     = 'USU_MOV_CIERRE'
         AND abreviatura = 'MOVCIERRE';
     EXCEPTION 
       WHEN OTHERS THEN 
         NULL;
   END;
  --REVERSION DEL DIA ANTERIOR
  BEGIN
     v_fecha_ant:=pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual,null,1);
    for m in movimientos loop
      v_usuario  := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');           
          -- Inicializar secuencia si es la primera vez para este usuario --
         IF NOT v_usu_secuencia.EXISTS(v_usuario) THEN
             v_usu_secuencia(v_usuario) := 0;
             v_usu_hora(v_usuario)      := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E'); 
         END IF;
         -- Si llega al limite de secuencias, recalcular hora y resetear
         IF v_usu_secuencia(v_usuario) >= 995 THEN
            v_usu_secuencia(v_usuario) := 1;
            v_usu_hora(v_usuario)      :=  PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
         ELSE
          -- Se incrementa la secuencia del usuario
            v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
         END IF;
      r_mvto.nro_secuencia     := v_usu_secuencia(v_usuario);
      r_mvto.cod_usuario       := v_usuario;
      r_mvto.hora              := v_usu_hora(v_usuario);
      r_mvto.cod_modulo        := m.cod_modulo;
      r_mvto.cod_modalidad     := m.cod_modalidad;
      r_mvto.cod_oficina       := m.cod_oficina;
      r_mvto.nro_cuenta        := m.nro_cuenta;
      r_mvto.cod_moneda        := m.cod_moneda;
      r_mvto.cod_tra_padre     := m.cod_tra_padre;
      r_mvto.cod_transaccion   := m.cod_transaccion;
      r_mvto.fecha             := v_fec_actual;
      r_mvto.fec_valor         := v_fec_actual;
      r_mvto.monto             := (m.monto) * -1;
      r_mvto.estado            := m.estado;
      r_mvto.est_cuenta        := m.est_cuenta;
      r_mvto.cod_ofi_origen    := m.cod_oficina;
      r_mvto.concepto          := m.concepto;
      r_mvto.reversado         := 'N';
      r_mvto.emi_aviso         := 'N';
      r_mvto.protegido         := 'N';
      r_mvto.cod_mod_padre     := m.cod_mod_padre;
      r_mvto.cod_mad_padre     := m.cod_modalidad;
      r_mvto.referencia        := 'REV.RECLAS.TARJETA';
      r_mvto.mto_equ_local     := m.mto_equ_local;
      r_mvto.cotizacion        := m.cotizacion;

      pag_gen.pr_ins_ge_movimiento(r_mvto);

    end loop;

  EXCEPTION
     when others then
       raise_application_error(-20282, 'Error. Cat.Tarjetas(Reversión..) '||sqlerrm);
  END;
   --*************FIN DE REVERSION **********************
   --*************RECATEGORIZACION **********************
   BEGIN

    FOR c IN cuentas LOOP
      IF c.new_categoria = 2 THEN
        v_cod_tra_hij := 923;--WA:06/01/2014 se cambia por 923 ----v_cod_tra_hij := 920;
        v_concepto    := 'TRANSF.CAP. A VENC-PF';
        v_est_cuenta  := 'V';
      ELSIF c.new_categoria in (3, 4) THEN
        v_cod_tra_hij := 921;
        v_concepto    := 'TRANSF.CAPITAL A EN GEST';
        v_est_cuenta  := 'G';
      ELSIF c.new_categoria in (5, 6) THEN
        v_cod_tra_hij := 922;
        v_concepto    := 'TRANSF.CAPITAL A MOROSA';
        v_est_cuenta  := 'M';
      ELSE
        v_est_cuenta  := c.new_categoria;
      END IF;

      v_usuario  := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');           
          -- Inicializar secuencia si es la primera vez para este usuario --
         IF NOT v_usu_secuencia.EXISTS(v_usuario) THEN
             v_usu_secuencia(v_usuario) := 0;
             v_usu_hora(v_usuario)      := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E'); 
         END IF;
         -- Si llega al limite de secuencias, recalcular hora y resetear
         IF v_usu_secuencia(v_usuario) >= 995 THEN
            v_usu_secuencia(v_usuario) := 1;
            v_usu_hora(v_usuario)      :=  PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
         ELSE
          -- Se incrementa la secuencia del usuario
            v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
         END IF;
      r_mvto.nro_secuencia   := v_usu_secuencia(v_usuario);
      r_mvto.cod_usuario     := v_usuario;
      r_mvto.hora            := v_usu_hora(v_usuario);
      r_mvto.cod_modulo      := c.cod_modulo;
      r_mvto.cod_modalidad   := c.cod_modalidad;
      r_mvto.cod_oficina     := c.cod_oficina;
      r_mvto.nro_cuenta      := c.nro_cuenta;
      r_mvto.cod_moneda      := c.cod_moneda;
      r_mvto.cod_tra_padre   := 945;
      r_mvto.cod_transaccion := v_cod_tra_hij;
      r_mvto.fecha           := v_fec_actual;
      r_mvto.fec_valor       := v_fec_actual;
      r_mvto.monto           := c.sal_tarjeta;
      r_mvto.estado          := 'N';
      r_mvto.est_cuenta      := v_est_cuenta;
      r_mvto.cod_ofi_origen  := c.cod_oficina;
      r_mvto.concepto        := v_concepto;
      r_mvto.reversado       := 'N';
      r_mvto.emi_aviso       := 'N';
      r_mvto.protegido       := 'N';
      r_mvto.cod_mod_padre   := c.cod_modulo;
      r_mvto.cod_mad_padre   := c.cod_modalidad;
      r_mvto.referencia      := 'RECLAS.TARJETA';

      IF c.cod_moneda = v_mon_local THEN
        r_mvto.mto_equ_local := NULL;
        r_mvto.cotizacion    := NULL;
      ELSE
        v_redondeo           := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', c.cod_modulo, c.cod_modalidad, v_mon_local);
        r_mvto.mto_equ_local := round(c.new_categoria * c.cotizacion, v_redondeo);
        r_mvto.cotizacion    := c.cotizacion;
      END IF;

      pag_gen.pr_ins_ge_movimiento(r_mvto);

    END LOOP;
    EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20282, 'Error. Cat.Tarjetas(Reclasif..) '||sqlerrm);
   END;

END PRT_CAM_CATEGORIA;
/
