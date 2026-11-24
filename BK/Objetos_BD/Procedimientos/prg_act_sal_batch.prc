CREATE OR REPLACE PROCEDURE IT.PRG_ACT_SAL_BATCH (
   p_min_nro_cuenta  ge_movimientos_res.NRO_CUENTA%TYPE  DEFAULT NULL,
   p_max_nro_cuenta  ge_movimientos_res.NRO_CUENTA%TYPE  DEFAULT NULL
)
AS
  l_error_count NUMBER;
 reg0 IT.TYP_LIS_ACT_SAL_BATCH;
 reg1 IT.TYP_LIS_ACT_SAL_BATCH;
 reg2 IT.TYP_LIS_ACT_SAL_BATCH;
 reg3 IT.TYP_LIS_ACT_SAL_BATCH;
 reg4 IT.TYP_LIS_ACT_SAL_BATCH;
 reg5 IT.TYP_LIS_ACT_SAL_BATCH;
 reg6 IT.TYP_LIS_ACT_SAL_BATCH;
 reg7 IT.TYP_LIS_ACT_SAL_BATCH;
 reg8 IT.TYP_LIS_ACT_SAL_BATCH;
 P_MOVIMIENTOS IT.TYP_LIS_ACT_SAL_BATCH;


 CURSOR CURSOR_MOV IS
  select IT.TYP_ACT_SAL_BATCH(ID,FEC_VALOR,anio,mes,monto_original,NRO_CUENTA,COD_MONEDA, 
                              COD_OFICINA,EST_CUENTA,REVERSADO,COD_TRANSACCION,COD_MODULO,
                              COD_MODALIDAD,FEC_MAX_INSERCION,PROCESADO,RUTINA1,TIPO,AFECTA, 
                              mto_debito,can_debito,monto,mto_credito,can_credito,afe_sal_total, 
                              afe_sal_retenido,afe_sal_bloqueado)
 from(
   select RES.ROWID ID,FEC_VALOR, 
          to_number(to_char(FEC_VALOR,'YYYY')) ANIO, 
          to_number(to_char(FEC_VALOR,'MM')) mes,
          monto as monto_original,NRO_CUENTA,COD_MONEDA,COD_OFICINA,EST_CUENTA,REVERSADO, 
          COD_TRANSACCION,COD_MODULO,COD_MODALIDAD,FEC_MAX_INSERCION,PROCESADO,RUTINA1,TIPO,AFECTA, 
          case when tipo = 'D' then monto
               else 0
          end as mto_debito,
          case when tipo = 'D' then 1
               else 0
          end as can_debito,
          case when tipo = 'D' then monto * -1
               else monto
          end as monto,
          case when tipo != 'D' then monto 
               else 0
          end as mto_credito,
          case when tipo != 'D' then 1 
               else 0
          end as can_credito,
          case when afecta  = 'R' then 
                      case when tipo = 'C' then 
                          case when tipo = 'D' then monto * -1   --monto
                          else monto
                          end
                      else 0
                      end
               WHEN afecta IN ('S','C','I') THEN 
                  case when tipo = 'D' then monto * -1 --monto
                       else monto
                  end
               ELSE 0
          end as afe_sal_total,
          case when afecta  = 'R' then 
              case when tipo in ('C','D') then 
                          case when tipo = 'D' then monto * -1   --monto
                          else monto
                          end
                   else 0
                  end
              else 0
              end as afe_sal_retenido,
          case when afecta  in  ('B') then 
                          case when tipo = 'D' then monto * -1   --monto
                          else monto
                          end
              else 0
              end
          as afe_sal_bloqueado
          from GE_MOVIMIENTOS_RES RES 
          where instr(0, nro_cuenta) = 0 --DYDMR-10076
          AND  PROCESADO='N' 
          AND RUTINA1 = 'PRA_ACT_SAL_BATCH'
          AND ( p_min_nro_cuenta IS NULL OR NRO_CUENTA >= p_min_nro_cuenta )
          AND ( p_max_nro_cuenta IS NULL OR NRO_CUENTA <= p_max_nro_cuenta )
          ORDER BY NRO_CUENTA, FEC_MAX_INSERCION
          );

              
BEGIN

    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;

   IF p_min_nro_cuenta IS NULL AND p_max_nro_cuenta IS NULL THEN
      PRG_ACT_LOG_PROCESOS('PRG_ACT_SAL_BATCH',1,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),'INICIO PRG_ACT_SAL_BATCH');
   END IF;

  IF cursor_mov%ISOPEN THEN
      CLOSE cursor_mov;
   END IF;
  OPEN cursor_mov;
      LOOP
       FETCH cursor_mov BULK COLLECT
            INTO P_MOVIMIENTOS LIMIT 5000; --LIMIT 1000000 ;

  select IT.TYP_ACT_SAL_BATCH(ROW_ID,FEC_VALOR,ANIO,MES,MONTO_ORIGINAL,NRO_CUENTA,COD_MONEDA,
                                  COD_OFICINA,EST_CUENTA,REVERSADO,COD_TRANSACCION	,COD_MODULO,COD_MODALIDAD,
                                  FEC_MAX_INSERCION,PROCESADO,RUTINA1,TIPO,AFECTA,MTO_DEBITO,CAN_DEBITO,MONTO, 
                                  MTO_CREDITO,CAN_CREDITO,AFE_SAL_TOTAL,AFE_SAL_RETENIDO,AFE_SAL_BLOQUEADO)
                                  bulk collect into reg0
                                  from table(P_MOVIMIENTOS) mov
  where mov.cod_modalidad in (31,334);
    
     BEGIN
      FORALL i IN 1 .. reg0.count SAVE EXCEPTIONS
       update AH_CTA_VISTAS
                 set SAL_TOT_BATCH = NVL(SAL_TOT_BATCH, 0) + reg0(i).AFE_SAL_TOTAL,
                     SAL_RET_BATCH = NVL(SAL_RET_BATCH, 0) + reg0(i).AFE_SAL_RETENIDO,
                     SAL_BLO_BATCH = NVL(SAL_BLO_BATCH, 0) + reg0(i).AFE_SAL_BLOQUEADO
               where NRO_CUENTA = reg0(i).NRO_CUENTA;  
      EXCEPTION WHEN OTHERS THEN
            l_error_count := SQL%BULK_EXCEPTIONS.count;
            if l_error_count >0 then
              FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT  LOOP
                  PRG_ACT_LOG_PROCESOS('PRG_ACT_SAL_BATCH',1,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),
                  'Error actualizando AH_CTA_VISTAS en Cta: '|| reg0(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) );
                  raise_application_error(-20000, 'Error actualizando AH_CTA_VISTAS en Cta: '|| reg0(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ' );
              END LOOP;  
             end if;   
      END;

    IF p_min_nro_cuenta IS NULL AND p_max_nro_cuenta IS NULL THEN
      FORALL x IN 1 .. reg0.count 
        update GE_MOVIMIENTOS_RES
        set PROCESADO = 'S'
        where rowid = reg0(x).row_id;
      COMMIT;
    END IF;
    
    select IT.TYP_ACT_SAL_BATCH(ROW_ID,FEC_VALOR ,ANIO,MES,MONTO_ORIGINAL,NRO_CUENTA,COD_MONEDA,
                                COD_OFICINA,EST_CUENTA,REVERSADO,COD_TRANSACCION,COD_MODULO,
                                COD_MODALIDAD,FEC_MAX_INSERCION,PROCESADO,RUTINA1,TIPO,AFECTA,
                                MTO_DEBITO,CAN_DEBITO,MONTO, MTO_CREDITO,CAN_CREDITO,AFE_SAL_TOTAL, 
                                AFE_SAL_RETENIDO,AFE_SAL_BLOQUEADO)
                               bulk collect into reg1
                               from table(P_MOVIMIENTOS) mov
   where mov.cod_modalidad in (31,334)
   AND (REVERSADO = 'N' OR (REVERSADO = 'S' AND NVL(TO_NUMBER(monto), 0) >=0));
   
    begin
    FORALL i IN 1 .. reg1.count SAVE EXCEPTIONS   
      update AH_SAL_MENSUALES
              set CAN_CREDITOS  = CAN_CREDITOS + reg1(i).CAN_CREDITO,
                  CAN_DEBITOS   = can_debitos + reg1(i).can_debito,
                  TOT_CREDITOS  = TOT_CREDITOS + reg1(i).MTO_CREDITO,
                  TOT_DEBITOS   = TOT_DEBITOS + reg1(i).MTO_DEBITO
            where NRO_CUENTA    = reg1(i).nro_cuenta    and
                  ANO           = reg1(i).anio          and
                  MES           = reg1(i).mes;
        EXCEPTION WHEN OTHERS THEN
          l_error_count := SQL%BULK_EXCEPTIONS.count;
          if l_error_count >0 then
            FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT  LOOP
                PRG_ACT_LOG_PROCESOS('PRG_ACT_SAL_BATCH',1,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),
                'Error actualizando AH_SAL_MENSUALES en Cta: '|| reg1(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) );
                raise_application_error(-20000, 'Error actualizando AH_SAL_MENSUALES en Cta: '|| reg1(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ' );
            END LOOP;  
           end if;
         END;

    IF p_min_nro_cuenta IS NULL AND p_max_nro_cuenta IS NULL THEN
      FORALL x IN 1 .. reg1.count 
        update GE_MOVIMIENTOS_RES
        set PROCESADO = 'S'
        where rowid = reg1(x).row_id;
      COMMIT;
    END IF;

   select IT.TYP_ACT_SAL_BATCH(ROW_ID,FEC_VALOR,ANIO,MES,MONTO_ORIGINAL,NRO_CUENTA,COD_MONEDA,
                               COD_OFICINA,EST_CUENTA,REVERSADO,COD_TRANSACCION,COD_MODULO,
                               COD_MODALIDAD,FEC_MAX_INSERCION,PROCESADO,RUTINA1,TIPO,AFECTA,
                               MTO_DEBITO,CAN_DEBITO,MONTO, MTO_CREDITO,CAN_CREDITO,AFE_SAL_TOTAL , 
                               AFE_SAL_RETENIDO,AFE_SAL_BLOQUEADO)
                               bulk collect into reg2
                               from table(P_MOVIMIENTOS) mov
   where mov.cod_modalidad in (31,334)
   and REVERSADO = 'S' and NVL(TO_NUMBER(monto),0) < 0 ;

     begin
     FORALL i IN 1 .. reg2.count SAVE EXCEPTIONS   
      update AH_SAL_MENSUALES
              set CAN_CREDITOS  = CAN_CREDITOS + reg2(i).CAN_CREDITO,
                  CAN_DEBITOS   = can_debitos + reg2(i).can_debito,
                  TOT_CREDITOS  = TOT_CREDITOS + reg2(i).MTO_CREDITO,
                  TOT_DEBITOS   = TOT_DEBITOS + reg2(i).MTO_DEBITO
            where NRO_CUENTA    = reg2(i).nro_cuenta    and
                  ANO           = reg2(i).anio          and
                  MES           = reg2(i).mes; 
      EXCEPTION WHEN OTHERS THEN
          l_error_count := SQL%BULK_EXCEPTIONS.count;
          if l_error_count >0 then
            FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT  LOOP
                PRG_ACT_LOG_PROCESOS('PRG_ACT_SAL_BATCH',1,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),
                'Error actualizando AH_SAL_MENSUALES en Cta: '|| reg2(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) );
                raise_application_error(-20000, 'Error actualizando AH_SAL_MENSUALES en Cta: '|| reg2(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ' );
            END LOOP;  
           end if;
       END;

    IF p_min_nro_cuenta IS NULL AND p_max_nro_cuenta IS NULL THEN
      FORALL x IN 1 .. reg2.count 
        update GE_MOVIMIENTOS_RES
        set PROCESADO = 'S'
        where rowid = reg2(x).row_id;
      COMMIT;
    END IF;

     select IT.TYP_ACT_SAL_BATCH(ROW_ID,FEC_VALOR,ANIO,MES,MONTO_ORIGINAL,NRO_CUENTA,COD_MONEDA,
                                     COD_OFICINA,EST_CUENTA,REVERSADO,COD_TRANSACCION,COD_MODULO,
                                     COD_MODALIDAD,FEC_MAX_INSERCION,PROCESADO,RUTINA1,TIPO,AFECTA,
                                     MTO_DEBITO,CAN_DEBITO,MONTO, MTO_CREDITO,CAN_CREDITO,AFE_SAL_TOTAL, 
                                     AFE_SAL_RETENIDO,AFE_SAL_BLOQUEADO)
   bulk collect into reg3
   from table(P_MOVIMIENTOS) mov
   where mov.cod_modalidad in  (32,37,38);
   
   BEGIN
    FORALL i IN 1 .. reg3.count SAVE EXCEPTIONS   
      update AH_CTA_PLAZOS
          set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + reg3(i).afe_sal_total,
              SAL_RET_BATCH = nvl(SAL_RET_BATCH,0) + reg3(i).afe_sal_retenido,
              SAL_BLO_BATCH = nvl(SAL_BLO_BATCH,0) + reg3(i).afe_sal_bloqueado
        where  NRO_CUENTA = reg3(i).nro_cuenta;        
        EXCEPTION WHEN OTHERS THEN
          l_error_count := SQL%BULK_EXCEPTIONS.count;
          if l_error_count >0 then
            FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT  LOOP
                PRG_ACT_LOG_PROCESOS('PRG_ACT_SAL_BATCH',1,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),
                'Error actualizando AH_CTA_PLAZOS en Cta: '|| reg3(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) );    
                raise_application_error(-20000, 'Error actualizando AH_CTA_PLAZOS en Cta: '|| reg3(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ' );
            END LOOP;  
           end if;
   END;

    IF p_min_nro_cuenta IS NULL AND p_max_nro_cuenta IS NULL THEN
      FORALL x IN 1 .. reg3.count 
        update GE_MOVIMIENTOS_RES
        set PROCESADO = 'S'
        where rowid = reg3(x).row_id;
      COMMIT;
    END IF;

   select IT.TYP_ACT_SAL_BATCH(ROW_ID, FEC_VALOR,ANIO,MES,MONTO_ORIGINAL,NRO_CUENTA,COD_MONEDA,
                                COD_OFICINA,EST_CUENTA,REVERSADO,COD_TRANSACCION,COD_MODULO,
                                COD_MODALIDAD,FEC_MAX_INSERCION,PROCESADO,RUTINA1,TIPO,AFECTA,
                                MTO_DEBITO,CAN_DEBITO,MONTO,MTO_CREDITO,CAN_CREDITO,AFE_SAL_TOTAL, 
                                AFE_SAL_RETENIDO,AFE_SAL_BLOQUEADO)
   bulk collect into reg4
   from table(P_MOVIMIENTOS) mov
   where mov.cod_modalidad IN (33,34,35,36);

   BEGIN 
    FORALL i IN 1 .. reg4.count SAVE EXCEPTIONS   
      update AH_CTA_CERTIFICADOS
          set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + reg4(i).afe_sal_total,
              SAL_RET_BATCH = nvl(SAL_RET_BATCH,0) + reg4(i).afe_sal_retenido,
              SAL_BLO_BATCH = nvl(SAL_BLO_BATCH,0) + reg4(i).afe_sal_bloqueado
        where NRO_CUENTA =  reg4(i).nro_cuenta;        
        EXCEPTION WHEN OTHERS THEN
          l_error_count := SQL%BULK_EXCEPTIONS.count;
          if l_error_count >0 then
            FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT  LOOP
                PRG_ACT_LOG_PROCESOS('PRG_ACT_SAL_BATCH',1,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),
                'Error actualizando AH_CTA_CERTIFICADOS en Cta: '|| reg4(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) );
                raise_application_error(-20000, 'Error actualizando AH_CTA_CERTIFICADOS en Cta: '|| reg4(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ' );
            END LOOP;  
           end if;
       END;

    IF p_min_nro_cuenta IS NULL AND p_max_nro_cuenta IS NULL THEN
      FORALL x IN 1 .. reg4.count 
        update GE_MOVIMIENTOS_RES
        set PROCESADO = 'S'
        where rowid = reg4(x).row_id;
      COMMIT;
    END IF;

   select IT.TYP_ACT_SAL_BATCH(ROW_ID,FEC_VALOR,ANIO,MES,MONTO_ORIGINAL,NRO_CUENTA,COD_MONEDA,
                                   COD_OFICINA,EST_CUENTA,REVERSADO,COD_TRANSACCION,COD_MODULO,
                                   COD_MODALIDAD,FEC_MAX_INSERCION,PROCESADO,RUTINA1,TIPO,AFECTA,
                                   MTO_DEBITO,CAN_DEBITO,MONTO,MTO_CREDITO,CAN_CREDITO,AFE_SAL_TOTAL, 
                                   AFE_SAL_RETENIDO,AFE_SAL_BLOQUEADO)
   bulk collect into reg5
   from table(P_MOVIMIENTOS) mov
   where mov.cod_modalidad IN (41);
   
   BEGIN
    FORALL i IN 1 .. reg5.count SAVE EXCEPTIONS   
       update CC_CTA_CORRIENTES
          set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + reg5(i).afe_sal_total,
              SAL_RET_BATCH = nvl(SAL_RET_BATCH,0) + reg5(i).afe_sal_retenido,
              SAL_BLO_BATCH = nvl(SAL_BLO_BATCH,0) + reg5(i).afe_sal_bloqueado
        where NRO_CUENTA =  reg5(i).nro_cuenta;    
         EXCEPTION WHEN OTHERS THEN
          l_error_count := SQL%BULK_EXCEPTIONS.count;
          if l_error_count >0 then
            FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT  LOOP
                PRG_ACT_LOG_PROCESOS('PRG_ACT_SAL_BATCH',1,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),
                'Error actualizando CC_CTA_CORRIENTES en Cta: '|| reg5(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) );
                raise_application_error(-20000, 'Error actualizando CC_CTA_CORRIENTES en Cta: '|| reg5(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ' );
            END LOOP;  
           end if;
       END;

    IF p_min_nro_cuenta IS NULL AND p_max_nro_cuenta IS NULL THEN
      FORALL x IN 1 .. reg5.count 
        update GE_MOVIMIENTOS_RES
        set PROCESADO = 'S'
        where rowid = reg5(x).row_id;
      COMMIT;
    END IF;

   select IT.TYP_ACT_SAL_BATCH(ROW_ID,FEC_VALOR,ANIO,MES,MONTO_ORIGINAL,NRO_CUENTA,COD_MONEDA,
                                   COD_OFICINA,EST_CUENTA,REVERSADO,COD_TRANSACCION,COD_MODULO,
                                   COD_MODALIDAD,FEC_MAX_INSERCION,PROCESADO,RUTINA1,TIPO,AFECTA,
                                   MTO_DEBITO,CAN_DEBITO,MONTO, MTO_CREDITO,CAN_CREDITO,AFE_SAL_TOTAL, 
                                   AFE_SAL_RETENIDO,AFE_SAL_BLOQUEADO)
   bulk collect into reg6
   from table(P_MOVIMIENTOS) mov
   where mov.cod_modalidad IN (41)
   AND (REVERSADO = 'N' OR (REVERSADO = 'S' AND NVL(TO_NUMBER(monto), 0) >=0));


   BEGIN
    FORALL i IN 1 .. reg6.count SAVE EXCEPTIONS   
       update CC_SAL_MENSUALES
                      set CAN_CREDITOS  = NVL(CAN_CREDITOS,0) + reg6(i).can_credito,
                          CAN_DEBITOS   = NVL(can_debitos,0) + reg6(i).can_debito,
                          TOT_CREDITOS  = NVL(TOT_CREDITOS,0)+ reg6(i).mto_credito,
                          TOT_DEBITOS   = NVL(TOT_DEBITOS,0) + reg6(i).mto_debito
                    where NRO_CUENTA = reg6(i).nro_cuenta and
                          ANO = reg6(i).anio              and
                          MES = reg6(i).mes;        
         EXCEPTION WHEN OTHERS THEN
          l_error_count := SQL%BULK_EXCEPTIONS.count;
          if l_error_count >0 then
            FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT  LOOP
                PRG_ACT_LOG_PROCESOS('PRG_ACT_SAL_BATCH',1,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),
                'Error actualizando CC_SAL_MENSUALES en Cta: '|| reg6(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) );
                raise_application_error(-20000, 'Error actualizando CC_SAL_MENSUALES en Cta: '|| reg6(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ' );
            END LOOP;  
           end if;
       END;

    IF p_min_nro_cuenta IS NULL AND p_max_nro_cuenta IS NULL THEN
      FORALL x IN 1 .. reg6.count 
        update GE_MOVIMIENTOS_RES
        set PROCESADO = 'S'
        where rowid = reg6(x).row_id;
      COMMIT;
    END IF;

   select IT.TYP_ACT_SAL_BATCH(ROW_ID,FEC_VALOR,ANIO,MES,MONTO_ORIGINAL,NRO_CUENTA,COD_MONEDA,
                                   COD_OFICINA,EST_CUENTA,REVERSADO,COD_TRANSACCION,COD_MODULO,
                                   COD_MODALIDAD,FEC_MAX_INSERCION,PROCESADO,RUTINA1,TIPO,AFECTA,
                                   MTO_DEBITO,CAN_DEBITO,MONTO, MTO_CREDITO,CAN_CREDITO,AFE_SAL_TOTAL, 
                                   AFE_SAL_RETENIDO,AFE_SAL_BLOQUEADO)
   bulk collect into reg7
   from table(P_MOVIMIENTOS) mov
   where mov.cod_modalidad IN (41)
   and REVERSADO = 'S' and NVL(TO_NUMBER(monto),0) < 0;


   BEGIN
    FORALL i IN 1 .. reg7.count SAVE EXCEPTIONS   
       update CC_SAL_MENSUALES
                      set CAN_CREDITOS  = NVL(CAN_CREDITOS,0) + reg7(i).can_credito,
                          CAN_DEBITOS   = NVL(can_debitos,0) + reg7(i).can_debito,
                          TOT_CREDITOS  = NVL(TOT_CREDITOS,0)+ reg7(i).mto_credito,
                          TOT_DEBITOS   = NVL(TOT_DEBITOS,0) + reg7(i).mto_debito
                    where NRO_CUENTA = reg7(i).nro_cuenta and
                          ANO = reg7(i).anio              and
                          MES = reg7(i).mes;        
         EXCEPTION WHEN OTHERS THEN
          l_error_count := SQL%BULK_EXCEPTIONS.count;
          if l_error_count >0 then
            FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT  LOOP
                PRG_ACT_LOG_PROCESOS('PRG_ACT_SAL_BATCH',1,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),
                'Error actualizando CC_SAL_MENSUALES en Cta: '|| reg7(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) );
                raise_application_error(-20000, 'Error actualizando CC_SAL_MENSUALES en Cta: '|| reg7(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ' );
            END LOOP;  
           end if;
       END;

    IF p_min_nro_cuenta IS NULL AND p_max_nro_cuenta IS NULL THEN
      FORALL x IN 1 .. reg7.count 
        update GE_MOVIMIENTOS_RES
        set PROCESADO = 'S'
        where rowid = reg7(x).row_id;
      COMMIT;
    END IF;
    
   select IT.TYP_ACT_SAL_BATCH(ROW_ID,FEC_VALOR ,ANIO,MES,MONTO_ORIGINAL,NRO_CUENTA,COD_MONEDA,
                                   COD_OFICINA ,EST_CUENTA,REVERSADO,COD_TRANSACCION,COD_MODULO,
                                   COD_MODALIDAD,FEC_MAX_INSERCION,PROCESADO,RUTINA1,TIPO,AFECTA,
                                   MTO_DEBITO,CAN_DEBITO,MONTO, MTO_CREDITO,CAN_CREDITO,AFE_SAL_TOTAL, 
                                   AFE_SAL_RETENIDO,AFE_SAL_BLOQUEADO)
   bulk collect into reg8
   from table(P_MOVIMIENTOS) mov
   where mov.cod_modalidad IN (42,43,44,45,46,47,48,49,442,455);

     
   BEGIN
    FORALL i IN 1 .. reg8.count SAVE EXCEPTIONS   
      update CC_CTA_BANCARIAS
          set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + reg8(i).afe_sal_total,
              SAL_RET_BATCH = nvl(SAL_RET_BATCH,0) + reg8(i).afe_sal_retenido,
              SAL_BLO_BATCH = nvl(SAL_BLO_BATCH,0) + reg8(i).afe_sal_bloqueado
        where NRO_CUENTA = reg8(i).nro_cuenta;          
        EXCEPTION WHEN OTHERS THEN
          l_error_count := SQL%BULK_EXCEPTIONS.count;
          if l_error_count >0 then
            FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT  LOOP
                PRG_ACT_LOG_PROCESOS('PRG_ACT_SAL_BATCH',1,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),
                'Error actualizando CC_CTA_BANCARIAS en Cta: '|| reg8(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) );
                raise_application_error(-20000, 'Error actualizando CC_CTA_BANCARIAS en Cta: '|| reg8(indx).nro_cuenta|| ' '||SQLERRM (-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ' );
            END LOOP;  
           end if;
       END;

    IF p_min_nro_cuenta IS NULL AND p_max_nro_cuenta IS NULL THEN
      FORALL x IN 1 .. reg8.count 
        update GE_MOVIMIENTOS_RES
        set PROCESADO = 'S'
        where rowid = reg8(x).row_id;
      COMMIT;
    END IF;

  EXIT WHEN cursor_mov%NOTFOUND;
    END LOOP;
    CLOSE cursor_mov;

   -- Confirmación explícita por si el sp es ejecutado con parámetros por fuera del PRA_ACT_CUENTAS
   -- Las llamadas desde fragmentos (chunks) al usar DBMS_PARALLEL_EXECUTE tienen confirmación implícita
   COMMIT;

   IF p_min_nro_cuenta IS NULL AND p_max_nro_cuenta IS NULL THEN
      PRG_ACT_LOG_PROCESOS('PRG_ACT_SAL_BATCH',1,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),'FIN PRG_ACT_SAL_BATCH');
   END IF;
END PRG_ACT_SAL_BATCH;
/
