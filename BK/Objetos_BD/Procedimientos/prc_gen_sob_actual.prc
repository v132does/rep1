CREATE OR REPLACE PROCEDURE IT.PRC_GEN_SOB_ACTUAL IS
--Definicion de Variables--
  R_GMOVI      ge_movimientos%rowtype;
  v_fec_actual DATE;
  V_HORA       ge_movimientos.hora%type;
  v_cdmodul    cc_cta_corrientes.cod_modulo%type;
  v_cdmodal    cc_cta_corrientes.cod_modalidad%type;
  v_cdofici    cc_cta_corrientes.cod_oficina%type;
  v_cdmoned    cc_cta_corrientes.cod_moneda%type;
  v_tieneac    cc_cta_corrientes.acu_sobregiro%type;
  v_sldeudo    ge_movimientos.monto%type;
  v_nrcuent    cc_cta_corrientes.nro_cuenta%type;
  v_cdtrans    ge_movimientos.cod_transaccion%type;
  v_cnmovim    ge_movimientos.concepto%type;
  v_cnconac    ge_movimientos.concepto%type := '';
  vAcuerdo     ge_movimientos.monto%type;
  vImporte     ge_movimientos.monto%type;
  vImtrans     ge_movimientos.monto%type;
  v_trconac    ge_movimientos.cod_transaccion%type; -- Transaccion de Sobregiro con acuerdo --
  v_secuencia  ge_movimientos.nro_secuencia%type := 0;
  v_redondeo   number(2) := 0;
  v_usu_mig_excluir varchar2(30);
  v_usuario  ba_usuarios.cod_usuario%type;
  v_can_user number;
  -- para asignacion de usuario
  TYPE typ_usu_secuencia IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
  v_usu_secuencia typ_usu_secuencia;
  
  TYPE t_usu_hor IS TABLE OF VARCHAR2(8) INDEX BY VARCHAR2(15);
  v_usu_hora t_usu_hor;

--Definicion de Cursores--
CURSOR cur3 IS
  select cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
         cod_moneda,acu_sobregiro,abs(nvl(sal_total,0) - nvl(sal_retenido,0) - nvl(sal_bloqueado,0))
    from cc_cta_corrientes
   where estado <> 'C'
     and cod_modalidad = 41
     and (v_usu_mig_excluir is null or usu_insercion <> v_usu_mig_excluir)
     and nvl(sal_total,0) - nvl(sal_retenido,0) - nvl(sal_bloqueado,0) < 0     ;
  
 
--Defincion de Procedimientos--
PROCEDURE LP_OBT_TRA_SITUACION
                       ( cdofici IN     NUMBER,
                         cdmodul IN     NUMBER,
                         cdmodal IN     NUMBER,
                         nrcuent IN     VARCHAR2,
                         cdtrans IN OUT NUMBER,
                         cnmovim IN OUT VARCHAR2,
                         trconac IN OUT NUMBER, --se usa con acuerdo
                         cnconac IN OUT VARCHAR2
                        ) IS
  cantdia NUMBER;

BEGIN
    cdtrans := 902;  /* Situacion vigente */
    cnmovim := 'SOBREG.VIGENTE: '||TO_CHAR(cantdia,'9999')||' DIAS';
    trconac := 942;
    cnconac := 'SOBREG.VIGENTE C/AC: '||TO_CHAR(cantdia,'9999')||' DIAS';
    SELECT can_dias
      INTO cantdia
      FROM cc_sobregiros_res
     WHERE nro_cuenta = nrcuent;
    IF NVL(cantdia,0) < 61 THEN
       cdtrans := 902;
       cnmovim := 'SOBREG.VIGENTE: '||TO_CHAR(cantdia,'9999')||' DIAS';
       trconac := 942;
       cnconac := 'SOBREG.VIGENTE C/AC: '||TO_CHAR(cantdia,'9999')||' DIAS';
    ELSIF cantdia < 91 THEN
       cdtrans := 909;
       cnmovim := 'SOBREG.VENCIDO: '||TO_CHAR(cantdia,'9999')||' DIAS';
       trconac := 949;
       cnconac := 'SOBREG.VENCIDO C/AC: '||TO_CHAR(cantdia,'9999')||' DIAS';
    ELSIF cantdia < 181 THEN
       cdtrans := 900;
       cnmovim := 'SOBREG.GESTION: '||TO_CHAR(cantdia,'9999')||' DIAS';
       trconac := 940;
       cnconac := 'SOBREG.GESTION C/AC: '||TO_CHAR(cantdia,'9999')||' DIAS';
    ELSIF cantdia < 361 THEN
       cdtrans := 912;
       cnmovim := 'SOBREG.MOROSO : '||TO_CHAR(cantdia,'9999')||' DIAS';
       trconac := 952;
       cnconac := 'SOBREG.MOROSO C/AC: '||TO_CHAR(cantdia,'9999')||' DIAS';
    ELSE
       cdtrans := 912;  /* igual a moroso, no hay cambio contable */
       cnmovim := 'SOBREG.IRRECUPERABLE:'||TO_CHAR(cantdia,'999999')||' DIAS';
       trconac := 952;  /* igual a moroso, no hay cambio contable */
       cnconac := 'SOB.IRRECUPERABLE C/AC:'||TO_CHAR(cantdia,'999999')||' DIAS';
    END IF;
EXCEPTION
 WHEN NO_DATA_FOUND THEN  NULL;
 WHEN TOO_MANY_ROWS THEN
    raise_application_error(-20001, 'Existen varios registros en CC_SOBREGIROS_RES');
 WHEN OTHERS THEN
    raise_application_error(-20002, SQLERRM);
END;
BEGIN
   --Traer la Fecha Actual--
   v_fec_actual := pag_cal.fu_obt_fec_actual(4);
   v_usu_mig_excluir := fug_obt_pardinamico('COD_USU_MIG_EXCLUIR');
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
   --
   --Inicializa Hora para los Movimientos--
    OPEN cur3;
    LOOP
      FETCH cur3 INTO v_cdmodul, v_cdmodal, v_cdofici, v_nrcuent,
                      v_cdmoned, v_tieneac, v_sldeudo;
      EXIT WHEN cur3%NOTFOUND;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cdmodul,null,v_cdmoned);
      Begin
           -- Sumo los acuerdos permanentes para ver si esta utilizando o no
           Select sum(monto)
             into vAcuerdo
             from cc_lin_sobregiros
            Where -- Se contabilizan también las líneas transitorias nvl(tipo, 'T') = 'P' and
                  nro_cuenta = v_nrcuent
              and fec_vencimiento >= v_fec_actual
              and estado = 'A';
           --
           vImporte := 0;
           vImtrans := 0;

           --Redondeo de importes
           vAcuerdo  := round(nvl(vAcuerdo,0),v_redondeo);
           v_sldeudo := round(nvl(v_sldeudo,0),v_redondeo);

           -- Verifica con que importe debe generar la transaccion
           vImtrans := v_sldeudo;

           /* Ya no debe generar el asiento por utilizacion 27-09-2000 OPGM*/
           If nvl(vAcuerdo, 0) >= v_sldeudo Then
              vImporte := v_sldeudo;
              vImtrans := 0;
           Elsif nvl(vAcuerdo, 0) > 0 and nvl(vAcuerdo, 0) < v_sldeudo Then
              vImporte := vAcuerdo;
              vImtrans := v_sldeudo - vAcuerdo;
           Else
              vImporte := 0;
              vImtrans := v_sldeudo;
           End If;
           --- verifico la situacion actual del sobregiro por dias
           lp_obt_tra_situacion(v_cdofici,v_cdmodul,v_cdmodal,
                                v_nrcuent,v_cdtrans,v_cnmovim,
                                v_trconac,v_cnconac);
           --- inserto en el fgdiari por el monto utilizado de la linea --
           /*If vImporte > 0 Then --se eliminó el campo
              -- Grabo en el fcsobre el sobregiro acordado --
              Update cc_sobregiros_res
                 set val_sobregiro = vImporte
               where nro_cuenta = v_nrcuent;
           End If;*/
           --si tiene alguno de los importes
           If vImtrans > 0 or vImporte > 0 Then
           -------------------------------------------------------------
           -- Ctrol para multiples usuario
           -- Inserto en ge_movimientos por el sobregiro sin acuerdo 
           -- Se obtiene nuevo usuario para el sgte nro_secuencia
            v_usuario  := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');  
           
           -- primera vez cada usuario es 0
           IF NOT v_usu_secuencia.EXISTS(v_usuario) THEN
              v_usu_secuencia(v_usuario) := 0;
              v_usu_hora(v_usuario) := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
           END IF; 
           
           if v_usu_secuencia(v_usuario) > 990 then 
              v_usu_hora(v_usuario)      := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
              v_usu_secuencia(v_usuario) := 0;
           end if;

           ------------------------------------------------------------
           
             r_gmovi.cod_modulo      := v_cdmodul;
             r_gmovi.cod_modalidad   := v_cdmodal;
             r_gmovi.cod_oficina     := v_cdofici;
             r_gmovi.nro_cuenta      := v_nrcuent;
             r_gmovi.cod_moneda      := v_cdmoned;
             r_gmovi.cod_usuario     := v_usuario;
             r_gmovi.hora            := v_usu_hora(v_usuario);
             r_gmovi.fecha           := v_fec_actual;
             --
             r_gmovi.fec_valor       := v_fec_actual;
             r_gmovi.cod_mod_padre   := v_cdmodul;
             r_gmovi.cod_mad_padre   := v_cdmodal;
             r_gmovi.nro_documento   := null;
             r_gmovi.nro_documento2  := null;
             r_gmovi.nro_documento3  := null;
             r_gmovi.cod_tasa        := null;
             r_gmovi.val_tasa        := null;
             r_gmovi.cotizacion      := null;
             r_gmovi.cod_ofi_origen  := v_cdofici;
             r_gmovi.emi_aviso       := 'N';
             r_gmovi.estado          := 'N';
             r_gmovi.reversado       := 'N';
             If vImporte > 0 then --con acuerdo
                v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
                r_gmovi.nro_secuencia   := v_usu_secuencia(v_usuario);
                r_gmovi.cod_tra_padre   := v_trconac;
                r_gmovi.cod_transaccion := v_trconac;
                r_gmovi.monto           := vImporte;
                r_gmovi.concepto        := v_cnconac;
                pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');               
             end if;
             if vImtrans > 0 then --sin acuerdo
                v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
                r_gmovi.nro_secuencia   := v_usu_secuencia(v_usuario);
                r_gmovi.cod_tra_padre   := v_cdtrans;
                r_gmovi.cod_transaccion := v_cdtrans;
                r_gmovi.monto           := vImtrans;
                r_gmovi.concepto        := v_cnmovim;
                pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
             end if;
           End If;         
      End;           
    END LOOP;   -- fin del ciclo de Principal
EXCEPTION
WHEN OTHERS THEN
   raise_application_error(-20003, 'ERROR. prc_gen_sob_actual '||SQLERRM);
END prc_gen_sob_actual;
