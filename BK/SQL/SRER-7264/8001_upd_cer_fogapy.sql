-- ============================================================
-- NOR-698 | T015 - Actualizacion NRO_DOCUMENTO en IT.PR_GAR_DOCUMENTOS
-- Poblar numero de certificado Fogapy (fuente: garantia_sin_documento.xlsx)
-- Campo a actualizar: NRO_DOCUMENTO  Condicion: campo NULL
-- Registros: 112  Fecha: 2026-07-22
-- ============================================================
-- Inicializar contexto Bankiti
BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
/

DECLARE
  v_upd  NUMBER := 0;
  v_skip NUMBER := 0;
BEGIN

  -- NRO_CUENTA: 3077325 | Certificado: 30187
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '30187'
  WHERE  NRO_GARANTIA  = 13319
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3281908 | Certificado: 41175
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '41175'
  WHERE  NRO_GARANTIA  = 14417
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3270915 | Certificado: 40768
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '40768'
  WHERE  NRO_GARANTIA  = 14401
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3091273 | Certificado: 32140
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '32140'
  WHERE  NRO_GARANTIA  = 14504
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3180776 | Certificado: 37805
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '37805'
  WHERE  NRO_GARANTIA  = 14798
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3069134 | Certificado: 28916
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '28916'
  WHERE  NRO_GARANTIA  = 14052
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 2947355 | Certificado: 9976
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '9976'
  WHERE  NRO_GARANTIA  = 13848
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3187457 | Certificado: 37935
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '37935'
  WHERE  NRO_GARANTIA  = 14800
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3128616 | Certificado: 34858
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '34858'
  WHERE  NRO_GARANTIA  = 15856
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3099205 | Certificado: 32878
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '32878'
  WHERE  NRO_GARANTIA  = 16467
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3268503 | Certificado: 40698
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '40698'
  WHERE  NRO_GARANTIA  = 14400
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3299338 | Certificado: 41793
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '41793'
  WHERE  NRO_GARANTIA  = 15385
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3365687 | Certificado: 44515
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '44515'
  WHERE  NRO_GARANTIA  = 16337
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3063200 | Certificado: 28302
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '28302'
  WHERE  NRO_GARANTIA  = 15722
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3306921 | Certificado: 42110
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '42110'
  WHERE  NRO_GARANTIA  = 15401
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3138109 | Certificado: 35401
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '35401'
  WHERE  NRO_GARANTIA  = 15868
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3061052 | Certificado: 27983
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '27983'
  WHERE  NRO_GARANTIA  = 15711
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3084670 | Certificado: 31304
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '31304'
  WHERE  NRO_GARANTIA  = 13336
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3107803 | Certificado: 33766
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '33766'
  WHERE  NRO_GARANTIA  = 13933
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3051465 | Certificado: 26423
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '26423'
  WHERE  NRO_GARANTIA  = 13988
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3339291 | Certificado: 43607
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '43607'
  WHERE  NRO_GARANTIA  = 13425
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3154978 | Certificado: 36457
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '36457'
  WHERE  NRO_GARANTIA  = 14770
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3340069 | Certificado: 43654
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '43654'
  WHERE  NRO_GARANTIA  = 13426
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3331718 | Certificado: 43392
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '43392'
  WHERE  NRO_GARANTIA  = 13417
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3059100 | Certificado: 27568
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '27568'
  WHERE  NRO_GARANTIA  = 15683
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3346667 | Certificado: 43811
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '43811'
  WHERE  NRO_GARANTIA  = 13427
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3310235 | Certificado: 42244
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '42244'
  WHERE  NRO_GARANTIA  = 15407
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3347926 | Certificado: 43843
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '43843'
  WHERE  NRO_GARANTIA  = 13428
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 2979055 | Certificado: 16635
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '16635'
  WHERE  NRO_GARANTIA  = 13889
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3094352 | Certificado: 32388
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '32388'
  WHERE  NRO_GARANTIA  = 14522
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3362205 | Certificado: 44378
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '44378'
  WHERE  NRO_GARANTIA  = 13443
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3321029 | Certificado: 42816
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '42816'
  WHERE  NRO_GARANTIA  = 13398
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3280209 | Certificado: 41107
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '41107'
  WHERE  NRO_GARANTIA  = 14416
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3020187 | Certificado: 22574
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '22574'
  WHERE  NRO_GARANTIA  = 15353
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3108802 | Certificado: 33977
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '33977'
  WHERE  NRO_GARANTIA  = 13948
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3326264 | Certificado: 43029
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '43029'
  WHERE  NRO_GARANTIA  = 13402
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3305838 | Certificado: 42081
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '42081'
  WHERE  NRO_GARANTIA  = 15400
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3318492 | Certificado: 42643
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '42643'
  WHERE  NRO_GARANTIA  = 15421
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3159914 | Certificado: 36659
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '36659'
  WHERE  NRO_GARANTIA  = 14777
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3292796 | Certificado: 41575
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '41575'
  WHERE  NRO_GARANTIA  = 15368
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3368949 | Certificado: 44639
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '44639'
  WHERE  NRO_GARANTIA  = 16342
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3035097 | Certificado: 24349
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '24349'
  WHERE  NRO_GARANTIA  = 14555
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3122762 | Certificado: 34573
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '34573'
  WHERE  NRO_GARANTIA  = 15851
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3368627 | Certificado: 44620
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '44620'
  WHERE  NRO_GARANTIA  = 16340
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3080828 | Certificado: 30827
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '30827'
  WHERE  NRO_GARANTIA  = 14214
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3112856 | Certificado: 34178
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '34178'
  WHERE  NRO_GARANTIA  = 15833
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3364939 | Certificado: 44484
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '44484'
  WHERE  NRO_GARANTIA  = 16336
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3153086 | Certificado: 36235
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '36235'
  WHERE  NRO_GARANTIA  = 14768
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3107402 | Certificado: 33696
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '33696'
  WHERE  NRO_GARANTIA  = 13928
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3151337 | Certificado: 36151
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '36151'
  WHERE  NRO_GARANTIA  = 14763
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3037165 | Certificado: 24609
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '24609'
  WHERE  NRO_GARANTIA  = 14562
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3272467 | Certificado: 40888
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '40888'
  WHERE  NRO_GARANTIA  = 14405
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3106835 | Certificado: 33612
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '33612'
  WHERE  NRO_GARANTIA  = 13921
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3307054 | Certificado: 42117
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '42117'
  WHERE  NRO_GARANTIA  = 15402
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3241189 | Certificado: 39821
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '39821'
  WHERE  NRO_GARANTIA  = 14388
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3349793 | Certificado: 43896
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '43896'
  WHERE  NRO_GARANTIA  = 13433
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3260166 | Certificado: 40410
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '40410'
  WHERE  NRO_GARANTIA  = 14396
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3322699 | Certificado: 42877
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '42877'
  WHERE  NRO_GARANTIA  = 13399
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3302995 | Certificado: 42020
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '42020'
  WHERE  NRO_GARANTIA  = 15398
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3293761 | Certificado: 41632
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '41632'
  WHERE  NRO_GARANTIA  = 15374
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3077104 | Certificado: 30140
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '30140'
  WHERE  NRO_GARANTIA  = 13316
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3095088 | Certificado: 32450
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '32450'
  WHERE  NRO_GARANTIA  = 14531
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3366255 | Certificado: 44536
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '44536'
  WHERE  NRO_GARANTIA  = 16338
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3292215 | Certificado: 41552
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '41552'
  WHERE  NRO_GARANTIA  = 14437
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3272017 | Certificado: 40916
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '40916'
  WHERE  NRO_GARANTIA  = 14404
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3006865 | Certificado: 21388
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '21388'
  WHERE  NRO_GARANTIA  = 15332
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3355074 | Certificado: 44106
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '44106'
  WHERE  NRO_GARANTIA  = 13438
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3319310 | Certificado: 42669
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '42669'
  WHERE  NRO_GARANTIA  = 15423
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 2962064 | Certificado: 13080
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '13080'
  WHERE  NRO_GARANTIA  = 13858
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3296453 | Certificado: 41701
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '41701'
  WHERE  NRO_GARANTIA  = 15377
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3330560 | Certificado: 43351
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '43351'
  WHERE  NRO_GARANTIA  = 13413
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3291596 | Certificado: 41523
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '41523'
  WHERE  NRO_GARANTIA  = 14432
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3102479 | Certificado: 33173
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '33173'
  WHERE  NRO_GARANTIA  = 16485
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 2920688 | Certificado: 1423
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '1423'
  WHERE  NRO_GARANTIA  = 14695
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3084977 | Certificado: 31326
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '31326'
  WHERE  NRO_GARANTIA  = 13340
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3311026 | Certificado: 42301
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '42301'
  WHERE  NRO_GARANTIA  = 15410
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3177418 | Certificado: 37569
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '37569'
  WHERE  NRO_GARANTIA  = 14796
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3237906 | Certificado: 39708
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '39708'
  WHERE  NRO_GARANTIA  = 14387
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3030048 | Certificado: 23721
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '23721'
  WHERE  NRO_GARANTIA  = 14553
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3106843 | Certificado: 33619
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '33619'
  WHERE  NRO_GARANTIA  = 13922
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3015324 | Certificado: 22117
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '22117'
  WHERE  NRO_GARANTIA  = 15347
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3310305 | Certificado: 42247
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '42247'
  WHERE  NRO_GARANTIA  = 15408
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3028527 | Certificado: 23599
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '23599'
  WHERE  NRO_GARANTIA  = 14550
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3249178 | Certificado: 40045
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '40045'
  WHERE  NRO_GARANTIA  = 14391
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3261836 | Certificado: 40490
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '40490'
  WHERE  NRO_GARANTIA  = 14398
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3330712 | Certificado: 43365
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '43365'
  WHERE  NRO_GARANTIA  = 13416
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3237761 | Certificado: 39703
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '39703'
  WHERE  NRO_GARANTIA  = 14386
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3076375 | Certificado: 30048
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '30048'
  WHERE  NRO_GARANTIA  = 13311
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3359915 | Certificado: 44310
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '44310'
  WHERE  NRO_GARANTIA  = 13440
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3084474 | Certificado: 31276
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '31276'
  WHERE  NRO_GARANTIA  = 14232
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3368532 | Certificado: 44615
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '44615'
  WHERE  NRO_GARANTIA  = 16339
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3213265 | Certificado: 38994
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '38994'
  WHERE  NRO_GARANTIA  = 14807
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3324297 | Certificado: 42961
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '42961'
  WHERE  NRO_GARANTIA  = 13400
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3028926 | Certificado: 23627
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '23627'
  WHERE  NRO_GARANTIA  = 14551
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3280208 | Certificado: 41106
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '41106'
  WHERE  NRO_GARANTIA  = 14415
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3272911 | Certificado: 40943
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '40943'
  WHERE  NRO_GARANTIA  = 14407
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3058206 | Certificado: 27479
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '27479'
  WHERE  NRO_GARANTIA  = 15675
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3095017 | Certificado: 32443
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '32443'
  WHERE  NRO_GARANTIA  = 14530
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3079563 | Certificado: 30507
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '30507'
  WHERE  NRO_GARANTIA  = 14188
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3086132 | Certificado: 31458
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '31458'
  WHERE  NRO_GARANTIA  = 13345
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3076860 | Certificado: 30113
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '30113'
  WHERE  NRO_GARANTIA  = 13313
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3028228 | Certificado: 23558
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '23558'
  WHERE  NRO_GARANTIA  = 14549
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3315783 | Certificado: 42541
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '42541'
  WHERE  NRO_GARANTIA  = 15416
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3152587 | Certificado: 36214
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '36214'
  WHERE  NRO_GARANTIA  = 14766
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3059662 | Certificado: 27696
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '27696'
  WHERE  NRO_GARANTIA  = 15689
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 2945209 | Certificado: 9760
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '9760'
  WHERE  NRO_GARANTIA  = 14706
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 2999839 | Certificado: 20554
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '20554'
  WHERE  NRO_GARANTIA  = 15321
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3096094 | Certificado: 32521
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '32521'
  WHERE  NRO_GARANTIA  = 14538
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3093540 | Certificado: 32302
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '32302'
  WHERE  NRO_GARANTIA  = 14515
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3104383 | Certificado: 33297
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '33297'
  WHERE  NRO_GARANTIA  = 16497
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3299742 | Certificado: 41813
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '41813'
  WHERE  NRO_GARANTIA  = 15389
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  -- NRO_CUENTA: 3289960 | Certificado: 41467
  UPDATE IT.PR_GAR_DOCUMENTOS
  SET    NRO_DOCUMENTO  = '41467'
  WHERE  NRO_GARANTIA  = 14429
  AND    NRO_SECUENCIA = 1
  AND    NRO_DOCUMENTO IS NULL;
  IF SQL%ROWCOUNT > 0 THEN v_upd  := v_upd  + 1;
  ELSE                     v_skip := v_skip + 1;
  END IF;

  COMMIT;

END;
/
