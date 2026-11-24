CREATE OR REPLACE PROCEDURE IT.TODO_PRESTAMOS2
as
begin
  /*
   pae_cnf.g_cod_modulo := 1;
  --Se borran los datos de las tablas a migrar
  delete fase3 where modulo = 'PRM';
  delete from errores_importacion_f3 where modulo = 'PRM';
  registrar_fase3('Borrados fase3 y ERRORES_IMPORTACION_F2','PRM');
  commit;

  delete from mi_pr_cuotas;
  registrar_fase3('Borrado MI_PR_CUOTAS','PRM');
  delete from mi_pr_cta_prestamos;
  registrar_fase3('Borrado MI_PR_CTA_PRESTAMOS','PRM');
  commit;

  --Se generan los números de cuenta de préstamos y se cargan en la tabla
  --LOANS_NUMERO_CUENTA varios datos necesarios para la migración a IT
   generar_numeros_cuenta_suc('LAA');

  --Se busca información histórica de las solicitudes de préstamo y se carga dicha información
  --en la tabla PR_INFO_SOLICITUD
    obtener_info_solicitud_pr;

  --Los sectores que no pudieron ser mapeados, quedan con el códig -1 en el campo SECTOR
  --de la tabla LOANS_NUMERO_CUENTA, se actualiza ese dato para la migración
  update loans_numero_cuenta set sector = '999' where sector = '-1';
  commit;
  
  --Por si acaso, habilitar el trigger que carga la tabla GE_CUENTAS
  --execute immediate 'alter trigger it.ta_pr_cta_prestamos enable';

  --Llamada a los procedimientos de migración
  -- CF mig_pr_lineas;
  -- CF mig_pr_lin_aplicaciones;
  mi_mig_pr_cta_prestamos;
  mi_mig_pr_cuotas_v3;
  -- CF mig_pr_chq_libradores;
  -- CF mig_pr_cta_gastos;
  -- CF mig_pr_previsiones;
  -- CF mig_pr_solicitudes;

  -- CF crear_pr_nros_cta;
  --Procedimiento creado por Daissy para cargar en IT.GE_CTAS_CLIENTES
  -- CF it_ge_cta_clientes_pr;
  */
  null;
end;
/

