CREATE OR REPLACE PROCEDURE IT.PRC_PRO_CHE_CER_VEN
 IS
V_CDUSUAR GE_MOVIMIENTOS.COD_USUARIO%TYPE;
V_HORA GE_MOVIMIENTOS.HORA%TYPE;
V_FECHA DATE;
V_NRSECUE GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE;
v_esctaol cc_cta_corrientes.estado%Type;
v_vlchcer cc_che_certificados.monto%TYPE;
v_fcc     varchar2(30);    -- rowid de la fila de cuentas corrientes --
v_fch     varchar2(30);    -- rowid de la fila de cheques            --
v_esmovim varchar2(1);
v_cdofior cc_cta_corrientes.cod_oficina%type;
v_cdmodul cc_cta_corrientes.cod_modulo%type;
v_cdmodal cc_cta_corrientes.cod_modalidad%type;
v_nrcuent cc_cta_corrientes.nro_cuenta%type;
v_nro_cta_certificado cc_cta_bancarias.nro_cuenta%type;
v_nrchequ cc_chequeras.nro_che_inicial%type;
v_chinici cc_chequeras.nro_che_inicial%type;
v_posicio number(3);
v_dia_cer number(3);
CURSOR chc IS
    select cte.rowid, cce.rowid,cte.estado, cce.monto,cte.cod_oficina,
           cte.cod_modulo, cte.cod_modalidad, cte.nro_cuenta, cce.nro_cheque,
           cce.nro_cta_certificado
    from   cc_che_certificados cce,
           cc_cta_corrientes   cte
    where  cce.fec_pago is null
      and  cce.nro_cuenta = cte.nro_cuenta
      and  cce.fecha + v_dia_cer <= v_fecha
    for update of cte.sal_total;
--
PROCEDURE LP_VAL_CHE_INI IS
BEGIN
    select max(nro_che_inicial)
      into v_chinici
      from cc_chequeras
     where nro_cuenta = v_nrcuent and
           nro_che_inicial <= v_nrchequ;
    IF SQL%FOUND THEN
      v_posicio :=  NVL(v_nrchequ,0) - NVL(v_chinici,0) + 1;
    END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
     RAISE_APPLICATION_ERROR (-20000,'ERROR. Numero de Cheque Invalido');
  WHEN TOO_MANY_ROWS THEN
     RAISE_APPLICATION_ERROR (-20000,'ERROR. Existe mas de un cheque con el mismo numero');
END;
--
PROCEDURE LP_ACT_CHEQUERA (P_NRCHEQU  IN  NUMBER ) IS
v_posicion    NUMBER(3);
v_est_cheques cc_chequeras.est_cheques%type;
v_estado      varchar2(1);
BEGIN
    SELECT est_cheques
    into v_est_cheques
    FROM cc_chequeras
   WHERE nro_cuenta = v_nrcuent
     AND p_nrchequ >= nro_che_inicial
     AND p_nrchequ <=  nro_che_inicial + (can_cheques - 1);
  v_posicion := p_nrchequ - v_chinici + 1;
  v_estado := substr(v_est_cheques,v_posicion,1);
    If v_estado = 'C' then
        UPDATE cc_chequeras
         set est_cheques = substr(est_cheques,1,v_posicion-1)||'E'||substr(est_cheques,v_posicion+1,length(est_cheques))
       where nro_cuenta = v_nrcuent
         and nro_che_inicial <= v_nrchequ;
    End if;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
     RAISE_APPLICATION_ERROR (-20000,v_nrcuent||' '||to_char(v_nrchequ));
END;
--
BEGIN
    v_dia_cer   := fug_obt_pardinamico('DIA_VAL_CERTIFICACION', 4, 41);
    v_fecha     := pag_cal.fu_obt_fec_actual(4);
    v_hora      := TO_CHAR(SYSDATE,'HH24:MI:SS');
    v_hora      := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
    v_cdusuar   := substr(user,1,10);
    v_nrsecue   := 0;
    IF CHC%ISOPEN THEN
     CLOSE CHC;
    END IF;
    OPEN chc;
    LOOP
        FETCH chc INTO v_fcc, v_fch, v_esctaol, v_vlchcer, v_cdofior,
                       v_cdmodul, v_cdmodal, v_nrcuent, v_nrchequ,
                       v_nro_cta_certificado;
        EXIT WHEN chc%NOTFOUND;
        IF v_esctaol IN ('C','T') THEN
           v_esmovim := 'E';
        ELSE
           v_esmovim := 'N';
        END IF;
        IF v_esmovim = 'N' THEN
           begin
               ------------------------------------------------------
               --  hace el credito a la cuenta
               ------------------------------------------------------
               update cc_cta_corrientes set
                     fec_ult_movimiento = v_fecha,
                     hor_ult_movimiento = v_hora,
                     sal_total = sal_total + v_vlchcer
               where rowid = v_fcc;
               ------------------------------------------------------
               --  genera diario -- movimiento de credito          --
               ------------------------------------------------------
               v_nrsecue := v_nrsecue + 1;
               insert into ge_movimientos
                   (cod_usuario,hora,nro_secuencia,
                    cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
                    cod_moneda,cod_tra_padre,cod_transaccion,fecha,
                    fec_valor,nro_documento,monto,estado,
                    emi_aviso,cod_ofi_origen,cod_mod_padre,cod_mad_padre,reversado, protegido)
               select v_cdusuar, v_hora, v_nrsecue  ,
                      cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
                      cod_moneda,334,602,v_fecha,
                      v_fecha,v_nrchequ,v_vlchcer,v_esmovim,
                      'S',v_cdofior,4,41,'N','N'
                 from cc_cta_corrientes cte
                where cte.rowid = v_fcc;
               ------------------------------------------------------
               --  hace el DEBITO a la cuenta especial
               ------------------------------------------------------
               update cc_cta_bancarias set
                      fec_ult_movimiento = v_fecha,
                      hor_ult_movimiento = v_hora,
                      sal_total = sal_total - v_vlchcer
               where  nro_cuenta = v_nro_cta_certificado;
               ------------------------------------------------------
               --  genera diario -- movimiento de DEBITO           --
               ------------------------------------------------------
               v_nrsecue := v_nrsecue + 1;
               insert into ge_movimientos
                   (cod_usuario,hora,nro_secuencia,
                    cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
                    cod_moneda,cod_tra_padre,cod_transaccion,fecha,
                    fec_valor,nro_documento,monto,estado,
                    cod_ofi_origen,cod_mod_padre,cod_mad_padre,
                    reversado, protegido)
             select v_cdusuar, v_hora, v_nrsecue,
                    cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
                    cod_moneda,334,548,v_fecha,
                    v_fecha,v_nrchequ,v_vlchcer,v_esmovim,
                    v_cdofior,4,41,'N','N'
               from cc_cta_bancarias
              where nro_cuenta = v_nro_cta_certificado;
               ---------------------------------------------------------
               --   Actualiza tabla CC_CHEQUEERAS --
               ---------------------------------------------------------
               LP_VAL_CHE_INI;
               LP_ACT_CHEQUERA(v_nrchequ);
               ---------------------------------------------------------
               --  elimina el registro de cheque certificado acreditado
               ---------------------------------------------------------
               DELETE cc_che_certificados
               WHERE  cc_che_certificados.rowid = v_fch;
           end;
        END IF;
        ----------------------------------------
        ----------------------------------------
    END LOOP;
    CLOSE CHC;
END;
/

