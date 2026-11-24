CREATE OR REPLACE PROCEDURE IT.PRG_REG_CAN_OPE_ATM_MES
 ( p_nro_cuenta in varchar2 default null ) is
  -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 05/2016 ---
  v_msj                 varchar2(4000);
  c_nom_proceso         varchar2(100) := 'PRG_REG_CAN_OPE_ATM_MES';
  v_fec_actual          date := pag_cal.FU_OBT_FEC_ACTUAL(3);
  v_fec_pri_dia_habil   date := pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(3);
  --
  v_lugar               VARCHAR2(300);
  v_cod_bco_entidad     ge_bancos.cod_banco%type := fug_obt_cod_banco; -- DYDMR-5533 
  v_cod_bco_fusion      ge_bancos.cod_banco%type := fug_obt_cod_ban_fusion; 
begin

  if v_fec_actual = v_fec_pri_dia_habil then
    v_lugar := 'TRUNCATE TABLE GE_CAN_OPE_ATM_MES ';
    sql_util.ejecute_dml('TRUNCATE TABLE GE_CAN_OPE_ATM_MES ', v_msj);
    IF v_msj IS NOT NULL THEN
      raise_application_error(-20000,c_nom_proceso||' - '||v_lugar||' - '||sqlerrm);
    END IF;
  else
    v_lugar := 'ACTUALIZANDO DATOS EN GE_CAN_OPE_ATM_MES ';
    MERGE INTO GE_CAN_OPE_ATM_MES a
    USING ( select m.nro_cuenta nro_cuenta,
                   g.cod_gru_transaccion cod_gru_transaccion,
                   count(1) cantidad
              from ge_movimientos m, ge_gru_transacciones_det g, gv_gru_tra_cob_car_atm c
             where (nro_cuenta = p_nro_cuenta or p_nro_cuenta is null) 
               and  m.cod_mod_padre = g.cod_modulo
               and m.cod_mad_padre = g.cod_modalidad
               and m.cod_tra_padre = g.cod_transaccion
               and estado = 'N'
               and reversado = 'N'
               and nvl(m.monto,0) >= 0 --- DYDMR-11036 Excluye Extornos de Op. no marcados como reversion
               and m.nro_cuenta is not null
               and g.cod_gru_transaccion = c.cod_gru_transaccion
               and c.ind_atm_propio = ( case
                                          when nvl(m.cod_banco,-1) = v_cod_bco_entidad  -- DYDMR-5533
                                                or m.nro_documento2 IN (select g.cod_atm
                                                                          from cj_atm_entidades g
                                                                         where g.estado = 'A')  
                                                or nvl(m.cod_banco,-1) = v_cod_bco_fusion                         
                                          then
                                            'S'
                                          else
                                            'N'
                                        end )
               and ( exists ( select 1
                                from ah_cta_vistas a
                               where estado not in ('T','C','A','X')
                                 and a.nro_cuenta = m.nro_cuenta
                                 and not exists (select 1
                                                   from ge_par_entes p
                                                  where p.parametro = 'NRO_CUENTA'
                                                    and p.val_parametro = a.nro_cuenta) -- cuenta sponsor
                             )
                          or exists ( select 1
                                        from cc_cta_corrientes a
                                       where estado not in ('T','C','A','X')
                                         and a.nro_cuenta = m.nro_cuenta
                                         and not exists (select 1
                                                           from ge_par_entes p
                                                          where p.parametro = 'NRO_CUENTA'
                                                            and p.val_parametro = a.nro_cuenta) -- cuenta sponsor
                                     )
                      )
               group by  m.nro_cuenta, g.cod_gru_transaccion ) b
    ON (a.nro_cuenta = b.nro_cuenta and a.cod_gru_transaccion = b.cod_gru_transaccion )
    WHEN MATCHED THEN
      UPDATE SET
        cantidad  = a.cantidad + b.cantidad
    WHEN NOT MATCHED THEN
      INSERT (nro_cuenta, cod_gru_transaccion, cantidad )
      VALUES (b.nro_cuenta, b.cod_gru_transaccion, b.cantidad);
  end if;
 
exception
  when others then
    rollback;
    --
    IF sqlcode <= -20000 THEN
      raise;
    else
      raise_application_error(-20000,c_nom_proceso||' - '||v_lugar||' - '||sqlerrm);
    End if;
end PRG_REG_CAN_OPE_ATM_MES;
/

