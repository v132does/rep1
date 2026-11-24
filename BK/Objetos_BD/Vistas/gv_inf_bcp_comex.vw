create or replace force view it.gv_inf_bcp_comex as
select t.fec_operacion,
         decode(t.cod_modalidad,75,'Ingreso de Divisas',72,'Egresos de Divisas') Modalidad,
         decode(t.cod_modalidad,75,'País Origen',72,'País Destino') Origen_Destino,
         fue_obt_des_pais(t.cod_pai_banco) País,
         t.cod_moneda Moneda,
         nvl(t.monto,0) Monto,
          -- OF Origen de Fondos.
         decode(nvl(tf.tip_fondo,'F'),'F','X',null) OF_PriPersona,
         decode(nvl(tf.tip_fondo,'F'),'E','X',null) OF_PriEmpresas,
         decode(nvl(tf.tip_fondo,'F'),'P','X',null) OF_Público,
         decode(nvl(tf.tip_fondo,'F'),'B','X',null) OF_PropiosBco,
         -- MT Motivo de Transacción.
         decode(nvl(tm.tip_motivo,'O'),'X','X',null) MT_Com_Ext_Bienes_y_Ser,
         decode(nvl(tm.tip_motivo,'O'),'I','X',null) MT_InvInsFinancieros,
         decode(nvl(tm.tip_motivo,'O'),'R','X',null) MT_InvBienesRaices,
         decode(nvl(tm.tip_motivo,'O'),'U','X',null) MT_RemesaUtilidades,
         decode(nvl(tm.tip_motivo,'O'),'D','X',null) MT_Donación,
         decode(nvl(tm.tip_motivo,'O'),'P','X',null) MT_Pago_de_Préstamos,
         decode(nvl(tm.tip_motivo,'O'),'O','X',null) MT_Otros_,
          -- FT Financiamiento de la Transacción.
         decode(nvl(tfi.tip_financiacion,'O'),'E','X',null) FT_Efectivo,
         decode(nvl(tfi.tip_financiacion,'O'),'D','X',null) FTDep_cBcoDeclarante,
         decode(nvl(tfi.tip_financiacion,'O'),'C','X',null) FTChe_cBcoPlaza,
         decode(nvl(tfi.tip_financiacion,'O'),'X','X',null) FTChe_PlazaExt,
         decode(nvl(tfi.tip_financiacion,'O'),'O','X',null) FTOtra
    from lc_transferencias t,
         (select val_minimo, val_maximo tip_fondo from ba_cod_referencias  where dominio = 'TRA_TIP_FONDO') tf,
         (select val_minimo, val_maximo tip_motivo from ba_cod_referencias where dominio = 'TRA_TIP_MOTIVO') tm,
         (select val_minimo, val_maximo tip_financiacion from ba_cod_referencias where dominio = 'TRA_TIP_FINANCIACION') tfi
   where t.tip_fondo =  tf.val_minimo(+)
     and t.tip_motivo = tm.val_minimo(+)
     and t.tip_financiacion = tfi.val_minimo(+)
     and t.cod_modalidad in (72,75)
order by 1
;

