begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
UPDATE    ba_consultas   SET DET_SQL = 'select t.cod_pre_aprobado, 
t.cod_pla_pre_aprobado, t.fec_ini_oferta, t.fec_fin_oferta, 
t.cod_usu_oficial, p.nom_completo, p.nro_documento,
       u.descripcion Segmento,
       p.dir_correo,
       t.mon_pre_aprobado,
       t.can_cuota,
       t.tip_amortizacion,
       t.cod_modalidad,
       t.cod_moneda,
       t.estado,
     t.usu_insercion,
       Decode(t.Estado,
              ''D'',
              ''Desembolsado'',
              ''C'',
              ''Vigente'',
              ''N'',
              ''Cancelado'',
              ''V'',
              ''Vencido'',
              ''R'',
              ''Rechazado'') Descripcion_Estado,
       t.mot_estado,
      t.fec_insercion,
      a.Nro_Cuenta As Cuenta_Prest,
       a.dia_atraso,
       a.sal_capital,
       a.sal_interes,
      d.val_parametro As Telefono,
       Nvl(tar.tip_tar_debito,''MV'') As TieneTarFisica,
       fug_val_con_uni_per(t.cod_persona)TieneCU,
       fue_obt_des_ciudad(1,dir.cod_ciudad)Ciudad
  from PR_PRE_APROBADOS t, BA_PERSONAS p,pr_Cta_prestamos a,ba_tab_dat_adicionales d,ge_clientes k,
  ge_seg_clientes u,
  (Select e.cod_persona,e.tip_tar_debito
 from ah_tar_debitos e
 Where e.tip_tar_debito = ''MF'' and e.cod_ent_procesadora = 1175
 and e.cod_est_solicitud = 0 and e.id_producto = 20
 and e.nro_emision = (select max(g.nro_emision)
        from ah_tar_debitos g where g.cod_persona = e.cod_persona
        And g.cod_ent_procesadora =1175))tar,
 (Select h.cod_ciudad,h.cod_persona From ba_direcciones h Where h.principal = ''S''
And h.tipo = ''P'' And h.cod_pais = 1 And h.cod_direccion =
                 (Select Max(v.cod_direccion) From ba_direcciones v Where v.cod_persona = h.cod_persona
                 And v.principal = ''S'' And v.cod_pais = 1))dir
 where t.cod_persona = p.cod_persona
   And t.Nro_Solicitud = a.Nro_Solicitud(+)
   And t.cod_persona = k.cod_persona(+)
   And k.cod_seg_cliente = u.cod_seg_cliente
   And t.cod_persona = d.referencia
   And t.cod_persona = tar.cod_persona(+)
   And t.cod_persona = dir.cod_persona(+)
   And d.parametro = ''CELULAR_ONBOARDING''
   and('||'&'||'P_FILTROS)', filtros = 'NULL'
WHERE cod_consulta = 'CD_PRE_APR';
 
DELETE FROM BA_PAR_CONSULTAS WHERE COD_CAMPO = 'COD_CLI' AND COD_CONSULTA = 'CD_PRE_APR';

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_PRE_APR', 'NRO_DOCU', 'p', null, 'F', 'IT', to_date('05-10-2023 11:49:15', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('05-10-2023 11:49:15', 'dd-mm-yyyy hh24:mi:ss'), 2, 'V', 'S', 'N', null);

 
commit;
/
