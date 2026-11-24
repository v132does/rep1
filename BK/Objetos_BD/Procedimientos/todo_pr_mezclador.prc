CREATE OR REPLACE PROCEDURE IT."TODO_PR_MEZCLADOR"
IS
/*
CURSOR c is SELECT * FROM it.pr_cta_prestamos;
  CURSOR cMig 
      IS 
    SELECT * 
      FROM mi_pr_cta_prestamos;

  cuenta it.pr_cta_prestamos%ROWTYPE;
  cuentaMig mi_pr_cta_prestamos%ROWTYPE;
  
  CURSOR cuotasIt 
      IS
    SELECT * 
      FROM it.pr_cuotas;

  NoSePudoUpdateCuota EXCEPTION;
  NoSePudoUpdatePrestamos EXCEPTION;
  
  cuotaIt it.pr_cuotas%ROWTYPE;*/
BEGIN
 /* delete from mig_pr_log where modulo='PRM';
  delete from mig_pr_error_log where modulo='PRM';
  COMMIT;
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  
  mig_pr_log_registrar('TODO_PR_MEZCLADOR: INICIO','PRM');
  --Buscamos cuotas que **existen** en IT 
  --y que no existen en MIG para cancelarlas
  mig_pr_log_registrar('Buscando cuotas que existen en IT '
                  ||'que no existen en MIG','PRM');
  OPEN cuotasIt;
  LOOP   
       BEGIN
         FETCH cuotasIt INTO cuotaIt;
         EXIT WHEN cuotasIt%NOTFOUND;
         DECLARE
           cuotaMig mi_pr_cuotas%ROWTYPE;
         BEGIN
           SELECT * INTO cuotaMig
             FROM mi_pr_cuotas mc
            WHERE mc.nro_cuota=cuotaIt.Nro_Cuota
              AND mc.nro_cuenta=cuotaIt.Nro_Cuenta;
           
           IF( cuotaMig.sal_interes<>cuotaIt.Sal_Interes 
              OR cuotaMig.sal_capital<>cuotaIt.Sal_Capital
              OR cuotaMig.sal_int_documentado<>cuotaIt.sal_int_documentado
              OR cuotaMig.val_recargo<>cuotaIt.val_recargo
              OR cuotaMig.estado<>cuotaIt.estado
              OR cuotaMig.sal_capital<>cuotaIt.Sal_Capital) 
           THEN
             mig_pr_log_registrar('UPDATE it.pr_cuotas WHERE nro_cuota='||cuotaIt.nro_cuota
             ||' AND nro_cuenta='||cuotaIt.nro_cuenta,'PRM');
             UPDATE it.pr_cuotas p
                SET ROW=cuotaIt
              WHERE p.nro_cuenta = cuotaIt.Nro_Cuenta
                AND p.nro_cuota = cuotaIt.Nro_Cuota;
             
           END IF;
           
           
         
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
              -- update cuotas
              mig_pr_log_registrar('Cuota encontrada. nro_cuota='||cuotaIt.nro_cuota,'PRM');
              UPDATE it.pr_cuotas c
                 SET c.estado='N'
                    ,SAL_CAPITAL=0
                    ,SAL_INTERES=0
               WHERE c.nro_cuota=cuotaIt.nro_cuota
                 AND c.nro_cuenta=cuotaIt.nro_cuenta;
              IF( SQL%NOTFOUND ) THEN
                RAISE NoSePudoUpdateCuota;
              END IF;
              mig_pr_log_registrar('UPDATE it.pr_cuotas, nro_cuota='||cuotaIt.nro_cuota
              ,'PRM');
              COMMIT;
         END;
         
       EXCEPTION
       WHEN NoSePudoUpdateCuota THEN
            rollback;
            mig_pr_error_log_registrar('TODO_PR_MEZCLADOR'
            ,cuotaIt.nro_cuota
            ,'ROLLBACK: Error, NoSePudoUpdateCuota. cuota#'||cuotaIt.nro_cuota
            ||'sqlerrm:'||sqlerrm
            ,'PRM');
            
       WHEN Others THEN
            rollback;
            mig_pr_error_log_registrar('TODO_PR_MEZCLADOR'
            ,cuotaIt.Nro_Cuota
            ,'ROLLBACK: Error, UNHANDLED. cuota#'||cuotaIt.Nro_Cuota
            ||'sqlerrm:'||sqlerrm
            ,'PRM');
       END;
  END LOOP;
  CLOSE cuotasIt;
  mig_pr_log_registrar('Fin de busqueda de cuotas','PRM');
  --checkeamos los prestamos que existen en IT que ya 
  --no existen en MIG para cancelar el prestamo
  
  mig_pr_log_registrar('Iniciando busqueda de prestamos que existen en IT y que no existen en MIG','PRM');
  OPEN c;
  LOOP
     BEGIN
       FETCH c INTO cuenta;
       EXIT WHEN c%NOTFOUND;
       DECLARE
       cuentaMig it.pr_cta_prestamos%ROWTYPE;
       BEGIN
          SELECT * INTO cuentaMig 
            FROM mi_pr_cta_prestamos 
           WHERE nro_cuenta = cuenta.nro_cuenta;
           
           IF( cuenta.sal_capital<>cuentaMig.sal_capital
            OR cuenta.sal_interes<>cuentaMig.sal_interes
            OR cuenta.estado<>cuentaMig.estado
            OR cuenta.can_cuo_pagadas<>cuentaMig.can_cuo_pagadas
            ) THEN 
           
              mig_pr_log_registrar('UPDATE it.pr_cta_prestamos WHERE nro_cuenta='
                               ||cuenta.nro_cuenta,'PRM');
               
               UPDATE it.pr_cta_prestamos p
                  SET ROW=cuenta
                WHERE p.nro_cuenta = cuenta.nro_cuenta;
            END IF;
       EXCEPTION
       WHEN NO_DATA_FOUND THEN
         mig_pr_log_registrar('Prestamo encontrado, nro_cuenta='||cuenta.nro_cuenta,'PRM');
          -- El prestamos no existe mas, lo cual significa
          -- que se pago entero
          -- Hacemos un UPDATE prestamo
         UPDATE it.pr_cta_prestamos p
            SET p.estado='N'
               ,p.est_anterior=p.estado
               ,p.sal_capital=0
               ,p.sal_interes=0
          WHERE p.nro_cuenta=cuenta.nro_cuenta;
          if( SQL%NOTFOUND ) THEN
              RAISE NoSePudoUpdatePrestamos;
          end if;
          -- LOGEAMOS
          mig_pr_log_registrar('UPDATE it.pr_cta_prestamos, nro_cuenta='||cuenta.nro_cuenta
          ,'PRM');
          COMMIT;
          
       END;
     EXCEPTION
     WHEN NoSePudoUpdatePrestamos THEN
       rollback;
       mig_pr_error_log_registrar('TODO_PR_MEZCLADOR'
       ,cuenta.nro_cuenta
       ,'ROLLBACK: Error, NoSePudoUpdatePrestamos. cuenta#'||cuenta.nro_cuenta
       ||'sqlerrm:'||sqlerrm
       ,'PRM');
     WHEN Others THEN
       rollback;
       mig_pr_error_log_registrar('TODO_PR_MEZCLADOR'
       ,cuenta.nro_cuenta
       ,'ROLLBACK: Error, UNHANDLED EXCEPTION. cuenta#'||cuenta.nro_cuenta
       ||'sqlerrm:'||sqlerrm
       ,'PRM');
     END;
  END LOOP;
  CLOSE c;
  
  mig_pr_log_registrar('Fin busqueda de prestamos','PRM');
  
  -- Buscamos prestamos que existan en MIG
  -- que no existan en IT para agregar. 
  mig_pr_log_registrar('Inicio de busqueda de prestamos nuevos','PRM');
 
  OPEN cMig;
  LOOP
     BEGIN
         FETCH cMig INTO cuentaMig;
         EXIT WHEN cMig%NOTFOUND;
         DECLARE
            nroCuenta it.pr_cta_prestamos.nro_cuenta%TYPE;
         BEGIN
            SELECT nro_cuenta INTO nroCuenta 
              FROM it.pr_cta_prestamos 
             WHERE nro_cuenta = cuentaMig.nro_cuenta;
             
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
            mig_pr_log_registrar('Prestamo nuevo encontrado, nro_cuenta='||cuentaMig.Nro_Cuenta,'PRM');
            -- Cuenta nueva.
            -- La cuenta que esta en MIG no esta
            -- en IT. Hay que agregar.
            DECLARE
              CURSOR cuotas IS 
                 SELECT * 
                   FROM mi_pr_cuotas c
                  WHERE c.nro_cuenta=cuentaMig.nro_cuenta;
                  
               cuota mi_pr_cuotas%ROWTYPE;
               nroCuotas int :=0;
               NoHayCuotas EXCEPTION;
               ClienteNoEncontradoEnLoans EXCEPTION;
               NoSePudoInsertarElCliente EXCEPTION;
            BEGIN
            
               -- insertamos el prestamo
               INSERT INTO it.pr_cta_prestamos 
               VALUES cuentaMig;
               mig_pr_log_registrar('Prestamo insertado','PRM');
               --insertamos las cuotas
               mig_pr_log_registrar('Buscando cuotas del nuevo prestamo ','PRM');
               OPEN cuotas;
               LOOP
                      FETCH cuotas INTO cuota;
                      EXIT WHEN cuotas%NOTFOUND;
                      INSERT INTO it.pr_cuotas VALUES cuota;
                      nroCuotas := nroCuotas+1;
                      mig_pr_log_registrar('Cuota insertada','PRM');
               END LOOP;
               CLOSE cuotas;
               
               if( nroCuotas=0 ) THEN
                   RAISE NoHayCuotas;
               END IF;         
               
               -- insertamos la relacion prestamo-cliente
               -- PARA ESA cuenta
               DECLARE
                  ctaCliente it.ge_cta_clientes%ROWTYPE;
                  str varchar2(7000);
               BEGIN
                  mig_pr_log_registrar('Insertando datos del cliente','PRM');
                  str := 'SELECT ln.sucursalfu,ln.account_number,0,6,ln.scheme_code,nuries,''P'' '
                  ||' FROM loans_numero_cuenta ln '
                  ||'WHERE ln.account_number='||cuentaMig.nro_cuenta;
                  dbms_output.put_line(str);
                  SELECT  ln.sucursalfu
                         ,ln.account_number
                         ,0
                         ,6
                         ,ln.scheme_code
                         ,nuries
                         ,'P' 
                    INTO  ctaCliente.cod_oficina
                         ,ctaCliente.nro_cuenta
                         ,ctaCliente.dig_verificador
                         ,ctaCliente.cod_modulo
                         ,ctaCliente.cod_modalidad
                         ,ctaCliente.cod_persona
                         ,ctaCliente.relacion
                    FROM loans_numero_cuenta ln
                   WHERE ln.account_number=cuentaMig.nro_cuenta;
                   
                   INSERT INTO it.ge_cta_clientes 
                   (cod_persona,nro_cuenta,dig_verificador,cod_oficina
                   ,cod_modulo,cod_modalidad,relacion) 
                   VALUES 
                   (ctaCliente.cod_persona,ctaCliente.nro_cuenta
                   ,ctaCliente.dig_verificador,ctaCliente.cod_oficina
                   ,ctaCliente.cod_modulo,ctaCliente.cod_modalidad
                   ,ctaCliente.relacion);
                   IF( SQL%NOTFOUND ) THEN 
                     RAISE NoSePudoInsertarElCliente;
                   END IF;
                   mig_pr_log_registrar('Cliente insertado en it.ge_cta_clientes','PRM');
                EXCEPTION
                WHEN NO_DATA_FOUND THEN
                -- SELECT INTO no devolvio un row
                   RAISE ClienteNoEncontradoEnLoans;
                END;
                
                COMMIT;
            EXCEPTION
            WHEN ClienteNoEncontradoEnLoans THEN
                 rollback;
                 mig_pr_error_log_registrar('TODO_PR_MEZCLADOR'
                 ,cuentaMig.nro_cuenta
                 ,'ERROR, ROLLBACK: ClienteNoEncontradoEnLoans, nro_cuenta#: '||cuentaMig.nro_cuenta||' sqlerrm: '||sqlerrm
                 ||'sqlerrm:'||sqlerrm
                 ,'PRM');
            WHEN NoHayCuotas THEN
                 rollback;
                 mig_pr_error_log_registrar('TODO_PR_MEZCLADOR'
                 ,cuentaMig.nro_cuenta
                 ,'ERROR, ROLLBACK: NoHayCuotas, nro_cuenta#: '||cuentaMig.nro_cuenta||' sqlerrm: '||sqlerrm
                 ||'sqlerrm:'||sqlerrm
                 ,'PRM');
            WHEN NoSePudoInsertarElCliente THEN
                 rollback;
                 mig_pr_error_log_registrar('TODO_PR_MEZCLADOR'
                 ,cuentaMig.nro_cuenta
                 ,'ERROR, ROLLBACK: NoSePudoInsertarElCliente, nro_cuenta#: '||cuentaMig.nro_cuenta||' sqlerrm: '||sqlerrm
                 ||'sqlerrm:'||sqlerrm
                 ,'PRM');
            WHEN Others THEN
                 rollback;
                 mig_pr_error_log_registrar('TODO_PR_MEZCLADOR'
                 ,cuentaMig.nro_cuenta
                 ,'ERROR, ROLLBACK: unhandled ex insertando la cuenta de MIG#: '||cuentaMig.nro_cuenta||' sqlerrm: '||sqlerrm
                 ||'sqlerrm:'||sqlerrm
                 ,'PRM');
            END;
         END;
       EXCEPTION
         When Others Then
             mig_pr_error_log_registrar('TODO_PR_MEZCLADOR'
             ,0
             ,'Unhandled error, will exit, sqlerrm was: '||sqlerrm 
             ,'PRM');
             exit;
             
       END;
  END LOOP;
  CLOSE cMig;
  mig_pr_log_registrar('Fin de busqueda de prestamos nuevos','PRM');

  mig_pr_log_registrar('FIN del procedimiento','PRM');
  */
  null;
END;
/

