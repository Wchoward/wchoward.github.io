---
title: 2021-01-12-BERT(1)_Tokenizer
date: 2021-01-12 15:49:54
tags:
- Bert
- 分词
categories:
- Deep Learning
- NLP
---

# 使用

```python
from transformers import BertTokenizer
self.bert_tokenizer = BertTokenizer.from_pretrained('bert_model_path')
indexed_tokens = self.bert_tokenizer.encode(example_text.strip(), add_special_tokens=True)
```



# encode流程



```python
# 1. BertTokenizer
# 2. PreTrainedTokenizer.encode
# 3. PreTrainedTokenizer.encode_plus
# 4. PreTrainedTokenizer.prepare_for_model
# 5. BertTokenizer.build_inputs_with_special_tokens (添加[CLS] [SEP])
```



1. 获取文本text

2. 读取词表vocab

   ```python
   def load_vocab(vocab_file):
       vocab = collections.OrderedDict()
       with open(vocab_file, "r", encoding="utf-8") as reader:
           tokens = reader.readlines()
       for index, token in enumerate(tokens):
           token = token.rstrip('\n')
           vocab[token] = index
       return vocab
   ```

   

3. 调用 encode方法 -> encode_plus方法

4. 获取输入文本对应的token id （get_input_ids）

   ```python
   def convert_tokens_to_ids(self, tokens):
   	ids = []
     for token in tokens:
     	ids.append(self._convert_token_to_id_with_added_voc(token))
     return ids
   
   def _convert_token_to_id_with_added_voc(self, token):
   	if token in self.added_tokens_encoder:
   		return self.added_tokens_encoder[token]
     return self._convert_token_to_id(token)
   
   def _convert_token_to_id(self, token):
   	return self.vocab.get(token, self.vocab.get(self.unk_token))
   ```

   其中对于不在vocab中的词，返回<unk>对应的id

5. 调用prepare_for_model方法返回Dictionary

   - `input_ids`
   - `token_type_ids`
   - `attention_mask`
   - `overflowing_tokens`
   - `num_truncated_tokens`
   - `special_tokens_mask`

6. TBD

