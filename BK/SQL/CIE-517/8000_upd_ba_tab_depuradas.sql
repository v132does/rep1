begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;  
/
UPDATE it.ba_tab_depuradas d 
   SET d.limite=500000
WHERE d.programado='N' 
  AND d.nom_tabla in ('GE_MOVIMIENTOS', 'PR_CTA_PRESTAMOS', 'CJ_LOG_GLO_PRO');

COMMIT;

UPDATE it.ba_tab_depuradas d 
   SET d.niv_paralell=10 
WHERE d.programado='N' AND D.NRO_ORDEN<=17;

COMMIT;
 
