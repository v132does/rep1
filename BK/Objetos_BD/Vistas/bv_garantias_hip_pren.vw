create or replace force view it.bv_garantias_hip_pren as
select fue_obt_nom_usuario(gc.cod_usu_oficial) GESTOR,
               o.descripcion oficina,
               g.cod_persona cod_persona,
               p.nom_completo nombre_del_cliente,
               g.nro_garantia nro_garantia,
               substr(g.observacion, 1, 300) descripcion,
               g.cod_moneda cod_de_moneda,
               gc.tot_deu_real deuda_activo,
               gc.tot_deu_contingente deuda_contingente,
               gc.tot_prevision monto_de_prevision,
               gc.cat_riesgo categoria_del_cliente,
               g.fec_inicio ,
               g.fec_vencimiento ,
               g.cod_moneda cod_moneda,
               g.valor valor_escritura,
               g.nro_escritura,
               pap_gar.FU_OBT_VAL_COMPUTABLE(g.nro_garantia) valor_computable,
               g.cod_mon_tasacion cod_moneda_com,
               decode(g.tipo, 'A', 'Abierta', 'C', 'Cerrada') tipo,
               g.estado estado,
               et.descripcion tasador,
               h.nro_finca nro_finca,
               h.fec_ult_tasacion fecha_tasacion,
               h.fec_vencimiento fecha_vto_tasacion,
               h.val_edilicio valor_edificio,
               h.val_terreno valor_terreno,
               h.val_vta_rapida valor_vta_rapida,
               es.descripcion aseguradora,
               h.nro_poliza nro_poliza,
               h.fec_vto_seguro fecha_vto_seguro,
               h.val_seguro valor_del_seguro,
               gt.descripcion tipo_gar
          from pr_garantias g
         inner join pr_gar_tipos gt on gt.cod_garantia = g.cod_garantia
         inner join ba_personas p on p.cod_persona = g.cod_persona
         inner join ge_clientes gc on gc.cod_persona = g.cod_persona
         inner join pr_gar_hipotecarias h on h.nro_garantia = g.nro_garantia
          left outer join ba_usuarios u on u.cod_usuario =
                                           g.cod_usu_entregado
          left outer join ba_oficinas o on o.cod_oficina = g.cod_oficina
          left outer join ge_entes es on es.cod_ente = h.cod_ent_seguro
          left outer join ge_entes et on et.cod_ente = h.cod_ent_tasador
        union
        select fue_obt_nom_usuario(gc.cod_usu_oficial) GESTOR,
               o.descripcion oficina,
               g.cod_persona cod_persona,
               p.nom_completo nombre_del_cliente,
               g.nro_garantia nro_garantia,
               substr(g.observacion, 1, 300) descripcion,
               g.cod_moneda cod_de_moneda,
               gc.tot_deu_real deuda_activo,
               gc.tot_deu_contingente deuda_contingente,
               gc.tot_prevision monto_de_prevision,
               gc.cat_riesgo categoria_del_cliente,
               g.fec_inicio,
               g.fec_vencimiento ,
               g.cod_moneda cod_moneda,
               g.valor valor_escritura,
               g.nro_escritura,
               pap_gar.FU_OBT_VAL_COMPUTABLE(g.nro_garantia) valor_computable,
               g.cod_mon_tasacion cod_moneda_com,
               decode(g.tipo, 'A', 'Abierta', 'C', 'Cerrada') tipo,
               g.estado estado,
               et.descripcion tasador,
               '' nro_finca,
               h.fec_inicio fecha_tasacion,
               h.fec_vencimiento fecha_vto_tasacion,
               0 valor_edificio,
               0 valor_terreno,
               h.val_vta_rapida valor_vta_rapida,
               es.descripcion aseguradora,
               h.nro_poliza nro_poliza,
               h.fec_vto_seguro fec_vto_seguro,
               h.val_seguro valor_del_seguro,
               gt.descripcion tipo_gar
          from pr_garantias g
         inner join pr_gar_tipos gt on gt.cod_garantia = g.cod_garantia
         inner join ba_personas p on p.cod_persona = g.cod_persona
         inner join ge_clientes gc on gc.cod_persona = g.cod_persona
         inner join pr_gar_vehiculos h on h.nro_garantia = g.nro_garantia
          left outer join ba_usuarios u on u.cod_usuario =
                                           g.cod_usu_entregado
          left outer join ba_oficinas o on o.cod_oficina = g.cod_oficina
          left outer join ge_entes es on es.cod_ente = h.cod_ent_seguro
          left outer join ge_entes et on et.cod_ente = h.cod_ent_tasador;

