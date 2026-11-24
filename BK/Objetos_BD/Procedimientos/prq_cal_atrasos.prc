CREATE OR REPLACE PROCEDURE IT.PRQ_CAL_ATRASOS(p_nro_contrato in varchar2 default null) is
  v_fec_actual ge_calendarios.fec_actual%type;
  /*Proceso diario que verifica estado de los Contratos vigentes de Cajas de Seguridad
  segun los dias de retraso en el pago de las cutoas*/
  cursor c1 is
     Select nro_contrato, cod_oficina, cod_caj_seguridad, estado, rowid registro
       from cs_contratos
      where (estado not in ('C','I', 'R'))
        and nro_contrato = nvl(p_nro_contrato, nro_contrato);

  v_dia_atraso pr_cta_prestamos.dia_atraso%type := 0;
  
BEGIN
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
  pag_cal.PR_OBT_DAT_CALENDAR(16);
  v_fec_actual := pag_cal.G_FEC_PROXIMA;  -- Del módulo de Caja de Seguridad.
  For r1 in c1 Loop
      --Calcula los dias de atraso
      SELECT MAX(round(v_fec_actual - FEC_VENCIMIENTO))
        INTO v_dia_atraso
        FROM cs_con_cuotas x
       WHERE  MONTO > 0
         and estado = 'P'
         AND NRO_CONTRATO = r1.nro_contrato;
       -- Pasa estado de Contrato de Activo a Moroso
       IF nvl(v_dia_atraso,0) > 0 then 
        if r1.estado = 'A' and to_number(fug_obt_pardinamico('CAJ_SEG_DIA_MORA'))>= v_dia_atraso then -- DYDMR-6007 -Se agrega estado Activo - 09/02/2017
           -- Actualiza el estado a Moroso
           --DYDMR-6007 --09/02/2017
            BEGIN   
               update cs_contratos
                  set estado = 'M'
                where rowid = r1.registro
                  and estado = 'A';
            EXCEPTION
               WHEN others THEN
                  raise_application_error(-20001,'Error al actualizar estado del Contrato. Nro:'||r1.nro_contrato||' '||sqlerrm);
            END;
        end if;      
         -- Actualiza los días de atraso
         BEGIN   
           update cs_contratos
              set dia_atraso = v_dia_atraso,
                  max_atraso = decode(sign(nvl(max_atraso,0)-nvl(v_dia_atraso,0)),-1,v_dia_atraso,max_atraso)
            where rowid = r1.registro;
          EXCEPTION
             WHEN others THEN
                raise_application_error(-20001,'Error al actualizar estado del Contrato. Nro:'||r1.nro_contrato||' '||sqlerrm);
          END;
       END IF;
       -- Pasa estado de Contrato de  Moroso a Activo
       IF nvl(v_dia_atraso,0) <= 0  then
          BEGIN
             update cs_contratos
                set estado = 'A',
                    dia_atraso = 0
              where rowid = r1.registro
                and estado = 'M';
          EXCEPTION
             WHEN others THEN
                raise_application_error(-20001,'Error al actualizar estado del Contrato. Nro:'||r1.nro_contrato||' '||sqlerrm);
          END;      
       END IF;     

  End Loop;
end PRQ_CAL_ATRASOS;
/

