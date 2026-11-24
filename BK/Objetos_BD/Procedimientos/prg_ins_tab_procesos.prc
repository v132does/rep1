create or replace procedure it.prg_ins_tab_procesos(p_fecha in date) is

v_fecha            date := pag_cal.fu_obt_fec_actual(1);
v_hor_inicio       varchar2(8);
v_hor_fin          varchar2(8);

---DESOPIMI-30 - Optimización de proceso PAB_RES.PR_INV_CTA_CONTABLE
---del Inicio Contable Automático y Manual - DYD-SDSL-3441

procedure lp_ins_tab_procesos is
begin
    -------------------------------------------
    /*- ACTUALIZACION HISTORICOS TEMPORALES -*/
   --------------------------------------------
  --Inserción de CB_SAL_INV_PROCESOS
  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  begin
    insert into CB_SAL_INV_PROCESOS
    select c.*
    from cb_sal_inventarios_his c
    where c.fecha = p_fecha;
  exception
    when others then
      RAISE_APPLICATION_ERROR(-20000,'Error en :Inserción de CB_SAL_INV_PROCESOS' || SQLERRM);
  end;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('PRG_ACT_TAB_HISTORICAS','insert-CB_SAL_INV_PROCESOS', v_fecha, v_hor_inicio, v_hor_fin);

  --Inserción de CB_SAL_INV_PROCESOS_DET
  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  begin
    insert into CB_SAL_INV_PROCESOS_DET
    select c.*
    from cb_sal_inventarios_det_his c
    where c.fecha = p_fecha;
  exception
    when others then
      RAISE_APPLICATION_ERROR(-20000,'Error en: Inserción de CB_SAL_INV_PROCESOS_DET '||SQLERRM);
  end;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('PRG_ACT_TAB_HISTORICAS','insert-CB_SAL_INV_PROCESOS_DET', v_fecha, v_hor_inicio, v_hor_fin);

exception
   when others then
      RAISE_APPLICATION_ERROR(-20000, 'Error en: lp_ins_tab_historicas ' || SQLERRM);

end;

begin
  ---Inicio: Procesamiento ---
  EXECUTE IMMEDIATE ('truncate table cb_sal_inv_procesos');
  EXECUTE IMMEDIATE ('truncate table cb_sal_inv_procesos_det');
  lp_ins_tab_procesos;

exception
   when others then
      RAISE_APPLICATION_ERROR(-20001, 'Error en: prg_act_tab_historicas ' || SQLERRM);

end prg_ins_tab_procesos;
/

