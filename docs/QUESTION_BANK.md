# Hunny Question Bank

A bank of weekly questions for the Question tab — written for a couple at
**the three-year mark**: the honeymoon haze is gone, you've each seen the
other's flaws and chosen to stay, routines have set in, and the big future
questions (marriage, kids, where to live, money) have stopped being
hypothetical. The research on this stage is consistent: closeness now comes
from **updating what you know about each other** (Gottman's love maps go
stale — the person you mapped in year one isn't the person you're with in
year three), **maintaining fondness and appreciation** on purpose, **doing
novel things together** (Aron's self-expansion studies), and **talking about
the future before it happens to you**.

Every question is phrased so **both partners answer it separately, then
compare answers** — that's how the Question tab works. One question per week
means this bank is several years of material.

Seeding a week works like any other weekly content (see
[DIRECTUS_SETUP.md](DIRECTUS_SETUP.md)):

```bash
API=https://api.opcw032522.uk
ADMIN_TOKEN=your_admin_static_token
WEEK=2026-09-07   # the Monday of the week this question should show

curl -sX POST "$API/items/questions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d "{\"week_start\":\"$WEEK\",\"text\":\"What's your favorite memory of us that I probably don't know about?\"}"
```

The unique `week_start` means each question runs exactly once — work through
the sections in any order. Mixing one heavy question with two light ones per
month keeps it fun.

Research this bank draws on:

- [Gottman: 75 Insightful Questions to Deepen Emotional Intimacy](https://www.gottman.com/blog/75-insightful-questions-to-deepen-emotional-intimacy/)
- [Gottman: Build Love Maps](https://www.gottman.com/blog/the-sound-relationship-house-build-love-maps/)
- [Arthur Aron's 36 Questions (The Experimental Generation of Interpersonal Closeness, 1997)](https://sunshine-parenting.com/wp-content/uploads/2018/02/Arons-36-Questions.pdf)
- [Esther Perel: When Do You Find Yourself Drawn to Your Partner in Long-Term Relationships?](https://www.estherperel.com/blog/when-are-you-drawn-to-your-partner-in-long-term-relationships)
- [Verywell Mind: From Honeymoon Phase to Lasting Commitment](https://www.verywellmind.com/transition-from-honeymoon-phase-to-long-lasting-commitment-7486526)

---

## 1. Love Maps, Updated (1–32)

You mapped each other in year one — but people change. These check whether
your map is of who they are *now*.

1. What's something you're really into right now that I might not realize means that much to you?
2. Who are the three people you talk to most often these days, and what do you love about each of them?
3. What's stressing you out this month that we haven't really talked about?
4. What's a small win from the last few weeks that you're quietly proud of?
5. What does an ideal day off look like for you these days — not theoretically, this season of life?
6. What's a song, show, or book you've loved lately, and what did it give you?
7. What are you most looking forward to right now?
8. What's something you're quietly worried about?
9. What's a goal you're working toward that I could cheer louder for?
10. Who in your life drains you right now, and who fills you up?
11. What's your favorite way to spend an hour completely alone?
12. What part of your daily routine matters most to you, and what would you gladly drop?
13. What's something about your work I probably don't know?
14. What's a dream you've never said out loud to me?
15. What's your biggest fear these days — not the abstract ones, the real one?
16. What do you actually think about on the commute home?
17. What habit are you trying to build (or break) right now, and how's it going?
18. When did you last cry, and what was it about?
19. What made you laugh hardest in the past month?
20. What's something you wish I asked you about more often?
21. What's a memory from before we met that still shapes who you are?
22. What's a belief you've changed your mind about in the last year?
23. What's your relationship with your body like these days?
24. What's harder for you now than it was five years ago — and what's easier?
25. What's a place that feels like "yours," and why?
26. What do you do when you can't sleep?
27. What's your relationship with your family like right now — honestly?
28. What's an ambition you've let go of, and are you at peace with that?
29. What compliment do you wish you received more often?
30. What's something about me you don't think I realize I do?
31. If you had a completely free Saturday with zero obligations, what would you actually do with it?
32. What's the best part of your life right now that has nothing to do with me — and nothing to do with you either, just circumstance?

## 2. The Story of Us (33–62)

Three years is a real archive. Revisit it before it blurs.

33. What's your favorite memory of us that I probably don't know means that much to you?
34. What was the moment you knew this was something serious?
35. What did you honestly think of me the very first time you saw me?
36. What's a tiny moment from our first year that you'd love to relive?
37. What's the funniest thing that's ever happened to us together?
38. What's the hardest thing we've been through as a couple, and what did it teach us?
39. What's something we survived together that made us stronger?
40. What's your favorite photo of us, and why that one?
41. What's a tradition we've accidentally started that you love?
42. What's the best meal we've ever had together?
43. What's the best trip we've taken so far — and what made it the best?
44. What's a trip that went wrong that we now laugh about?
45. What did you learn about me in year one that still holds true?
46. What's something about me you've learned only in the last year?
47. How are we different as a couple today than we were a year ago?
48. What "first" are you glad we still have ahead of us?
49. What's a song that instantly takes you back to us?
50. Where were you in life when we met, and how did meeting me change its direction?
51. What's the kindest thing I've ever done for you?
52. What's an ordinary evening we had that you remember fondly?
53. What's your favorite thing about the little world we've built — our home, our routine, our corner of life?
54. What do you think our friends would call "so us"?
55. If our relationship were a movie, which scene would be the trailer moment?
56. What's something we used to do together that you miss and want to bring back?
57. What's the best gift I've ever given you, and why did it land?
58. What inside joke of ours do you love most?
59. What's a promise you feel we've kept to each other?
60. What did your family first say about me — be honest?
61. What's the moment in the last year you felt closest to me?
62. When you imagine us old, what picture comes to mind first?

## 3. Fondness & Admiration (63–92)

Gottman's finding: lasting couples keep a running culture of appreciation.
At year three, fondness needs maintenance like anything else.

63. What do you admire most about how I handle hard things?
64. What's a talent of mine you'd never trade for anything?
65. What's something I do without thinking that you love?
66. What made you proud of me this year?
67. What's the most attractive thing about the way I think?
68. In what way have I grown since we met that impresses you?
69. What's your favorite of my quirks?
70. When did you last brag about me to someone, and what did you say?
71. What's something I do for you that you've never properly thanked me for?
72. What's your favorite way I show love without words?
73. What do I do that instantly makes your day better?
74. What's the nicest thing you've ever thought about me but never said out loud?
75. What quality do we have as a couple that you hope we never lose?
76. What's the best advice I've ever given you?
77. What's something you find beautiful about me that has nothing to do with how I look?
78. What do you think I undervalue about myself?
79. What's your favorite photo of just me, and why?
80. What's a weakness of mine you find weirdly endearing?
81. What did you say about me when you first told your friends?
82. What's the smartest thing you've ever seen me do?
83. What's the bravest?
84. What's my superpower in this relationship?
85. What's one small thing I did this week that you appreciated?
86. What do you respect about how I treat other people?
87. What habit of mine inspires you?
88. What's something about me that surprised you recently — in a good way?
89. If you had to describe me to a stranger in three words, which three?
90. What's the most loving thing I've said to you this year?
91. What do you hope I never change about myself?
92. What do you feel when you see my name pop up on your phone?

## 4. Dreams & the Next Three Years (93–122)

The first three years happened to you. The next three get chosen.

93. What's your biggest dream for us over the next three years?
94. Where do you want to be living in three years, and why there?
95. What's a dream you've postponed that you want back on the table?
96. If money were no object, how would we spend our lives?
97. What's on your bucket list that you haven't told me about yet?
98. Describe your dream home — the rooms that actually matter and what happens in them.
99. What's a skill you'd want us to learn together?
100. What would your perfect birthday look like in an ideal world?
101. What's the one place you want us to see together more than anywhere else?
102. What do you hope our lives look like at the ten-year mark?
103. What's one thing you want to achieve this year, and how can I help?
104. What would make next year feel like a success to you by next December?
105. What's a tradition you'd like us to start?
106. What does "making it" look like to you?
107. What's a dream from childhood that still tugs at you?
108. What adventure should we plan for next year?
109. What's something you want us to say yes to more often?
110. What's something we should say no to more often?
111. What do you want our weekends to feel like a year from now?
112. What "someday" should we finally put a real date on?
113. If you could design our ideal ordinary Tuesday five years from now, what happens in it?
114. What do you want to be true about us in five years that isn't true yet?
115. What's a financial dream — not the number, the life it buys?
116. What kind of old people do you want us to be?
117. What's a fear about the future that I could help soften?
118. If we moved anywhere next month, where would your heart vote for?
119. What's something you want to do while we're young that we keep putting off?
120. What chapter of your life are you excited to close, and what one are you excited to open?
121. What would you attempt if you knew I'd be cheering the whole way?
122. What's a dream you have for me that you want me to take more seriously?

## 5. The Real-Deal Future (123–150)

Marriage, kids, roots, careers — the questions that stop being hypothetical
around year three. Best answered curious, not loaded.

123. How do you picture marriage — and is it something you want?
124. What did you grow up believing marriage was supposed to be?
125. What does commitment mean to you beyond just staying together?
126. Do you want kids — and what kind of parent do you think you'd be?
127. What did your parents get right that you'd want to repeat, and what would you do differently?
128. How many kids feels right to you, if any — and what's driving that number?
129. What are your honest thoughts on pets in our future?
130. Where do you want to put down roots — near family, far from it, or somewhere brand new?
131. What would need to be true for you to feel ready for the next big step with me?
132. What's your instinctive timeline for the next five years — no pressure, just gut?
133. How do you feel about combining finances — what excites you, what scares you?
134. If our careers ever competed, how do you think we should choose — and would you actually follow that rule?
135. How do you want to handle holidays once we have a family of our own?
136. What does a forever home need to have for you?
137. What role do you want our parents to play in our household someday?
138. What would you want to keep just yours, even after we fully merge lives?
139. How would you want us to handle it if one of us got a dream offer far away?
140. What's your take on weddings — big, small, or elopement — if it's on the table?
141. What would you want future kids to say about us as parents?
142. What values do you absolutely want to pass down?
143. What's your honest feeling about growing old — and what do you most want beside you when it comes?
144. What's your theory on what makes a couple last fifty years?
145. What's one thing about the future that keeps you up at night that we should actually plan for?
146. What does a good life mean to you at 40? At 60?
147. What would you do differently than the couples around us?
148. What does your gut say about us in ten years?
149. If we designed our life from a blank page, what's the first thing you'd draw?
150. What should partnership look like on the worst days — what are we each allowed to be then?

## 6. Money & the Practical Life (151–174)

Money fights are rarely about money — they're about history, security, and
control. Year three is when these stop being avoidable.

151. How did your family talk about money — or not talk about it — and what did it teach you?
152. Are you a saver, a spender, or something else — and has being with me changed it?
153. What does "enough" mean to you right now?
154. What's a purchase you'd defend forever?
155. What's a purchase you regret?
156. What's your honest reaction when you check your bank balance?
157. What's one money habit of mine you find charming, and one that quietly stresses you?
158. What are we saving for — and are we saving for it on purpose?
159. If $10,000 landed in our account tomorrow, what would you want to do with it?
160. What does financial security feel like to you — a number, a state of mind, or something else?
161. What's your philosophy on debt?
162. How did you learn to budget — or did you?
163. What would you do if money were a non-issue for exactly one year?
164. What's worth overpaying for, in your book?
165. What's never worth the money?
166. How do you feel about lending money to family or friends?
167. What's your ideal way to split shared expenses, and why?
168. What "treat yourself" line item would you always defend in our budget?
169. What money goal would make you proudest a year from now?
170. How should we make big purchases together — research everything, sleep on it, or jump?
171. What's your relationship with retirement — do you think about it, avoid it, or have a plan?
172. What's something cheap that makes your life feel rich?
173. What's your honest take on prenups?
174. What would you want to teach our kids — someday or now — about money?

## 7. How We Fight & How We Fix It (175–204)

Conflict is normal; repair is the skill. Year three is when your fight
patterns are set — name them while they're still fixable.

175. What does an argument look like from your side that I probably see completely differently?
176. What's the real topic hiding underneath our most common argument?
177. What do you need in the first five minutes of a disagreement?
178. When you go quiet, what's actually happening inside?
179. What's the best way to approach you when you're upset with me?
180. Which of my repair attempts actually work — and which ones backfire?
181. What did conflict look like in your house growing up?
182. What does your body language say when you're hurt that I might be misreading?
183. What would an apology that actually lands for you sound like?
184. What do we argue about that's secretly about something else?
185. What's a fight we've had that you're glad we had?
186. What's something you've said in a fight that you'd take back?
187. What's something you've wanted to say in a fight but held — and should it be said?
188. How much cool-down time do you need before you can talk something through?
189. What topics feel too tender to argue about casually?
190. When I criticize you, what does it hit?
191. What's the difference, for you, between a complaint and an attack?
192. What boundary around fights should we agree to — no phones, no midnight blowups, no bringing up March?
193. What does contempt look like in small doses, and what's our antidote?
194. What's the kindest thing either of us has done mid-argument?
195. What helps you actually hear me when you're feeling defensive?
196. What's your tell that a fight is truly over versus just paused?
197. After a fight, what makes reconnecting feel natural for you?
198. What recurring fight should we retire — and what would retiring it actually take?
199. What's something I do during conflict that's really about me, not the issue?
200. What do you need to hear when you're overwhelmed, even if the problem isn't solved yet?
201. How did your family make up after fights — and what did you inherit from that?
202. Honest opinion: do we fight too much, too little, or about right?
203. What's your fight-avoider move, and what does it cost us?
204. What do you want kids — someday or now — to see when we disagree?

## 8. Trust, Safety & the Hard Stuff (205–232)

The questions couples at three years assume they've already covered — and
usually haven't.

205. When do you feel safest with me?
206. What's something you've never told me because the moment never seemed right?
207. What's a fear about us that you've carried quietly?
208. What's something I should never joke about?
209. What does betrayal mean to you — where exactly is your line?
210. What's a secret you once kept from someone that you'd never repeat?
211. What would make it easier for you to tell me hard things?
212. What's the hardest thing you've ever had to admit to yourself?
213. When have you felt most alone in this relationship?
214. What's something you're afraid to want out loud?
215. What's a part of yourself you're still learning to accept?
216. What do you do with feelings you don't want to burden me with?
217. What's something you pretend doesn't bother you that actually does?
218. If you could ask me anything and get a guaranteed honest answer, what would you ask?
219. What could I do that would hurt your trust without my even realizing it?
220. What rebuilds your trust in people when it's been shaken?
221. What's a wound from before us that still aches sometimes?
222. What do you need from me on your worst days, even when you say you're fine?
223. What's an insecurity that flares up around you — no one's fault, but real?
224. What does emotional safety actually feel like in your body?
225. What's the bravest emotional thing you've ever done?
226. Who else in your life gets to see you fully yourself — and what do they get that others don't?
227. What's something you're practicing being more honest about?
228. When you imagine losing me, what fear comes first?
229. What would you want me to do if I ever noticed you drifting away?
230. What promise do you most want to hear from me — for real?
231. What's the hardest conversation we still haven't had?
232. What's a boundary you've never named out loud but always feel?

## 9. Desire & Intimacy (233–256)

Perel's insight: love craves closeness, but desire needs a little distance
and mystery. These are for talking about it before it becomes a problem.

233. When do you find yourself most drawn to me these days?
234. What's something I do that's completely unsexy — and something that's unexpectedly attractive?
235. What do you miss that we used to do, and what do you want more of now?
236. What makes you feel desired — not just loved, but *desired*?
237. What's the real recipe for getting you in the mood?
238. What's the sexiest non-sexual thing we do?
239. What's something you'd want us to try that you've never quite mentioned?
240. What kills the mood fastest for you?
241. How should we signal interest to each other — and how do you wish I'd read yours?
242. What's your favorite memory of us being close?
243. What does intimacy mean to you beyond the physical?
244. What's something about your own desires you're still figuring out?
245. What helps you get out of your head and into the moment?
246. What would a whole perfect day shaped around closeness look like for you?
247. When do you feel most seen by me?
248. What would make kissing feel like the first time again?
249. What's your honest review of our physical life right now — pacing, amount, depth?
250. How much "you time" feeds our "us time" — what does desire need from distance?
251. What's something you used to do for yourself that made you feel magnetic — would you bring it back?
252. Do we still flirt? What would more of it look like?
253. What would your perfect night in include?
254. What compliment about your body would you love to hear more often?
255. What's one small ritual of touch — non-sexual — you'd want every day?
256. What's something you want to tell me about what you like, that this question just made room for?

## 10. Rituals, Routines & the Ordinary (257–280)

At three years, the daily grind *is* the relationship. Design it on purpose.

257. What's your favorite part of our daily routine — and the part you'd vote to change?
258. What small ritual of ours do you treasure most?
259. What's our best shared habit, and our worst?
260. What does a perfect weeknight look like in this season of our life?
261. What chore do you secretly not mind — and which one drains your soul?
262. What would make mornings better for you?
263. What's our ideal Sunday, hour by hour?
264. What's a meal you'd be happy eating every single week forever?
265. What household rule would you want us to agree on for good?
266. What do you love about how we've set up our home? What's it missing?
267. What tiny luxury should we budget for routinely?
268. What's your favorite way to decompress after work — and how can I protect that time?
269. What's our best lazy-day tradition?
270. What do you wish we did more of on an average week?
271. What's something routine that *you* do that you think I take for granted?
272. What ritual from your childhood do you want in our home?
273. What date-night format actually works for us — and which one doesn't?
274. How do you feel about our screen habits when we're together?
275. What's the best part of coming home to each other?
276. What's a small sign that we're doing well, even when life is chaotic?
277. What warning sign should we name now so we can catch it early?
278. What do you want us to do every single anniversary, no matter what?
279. What should the first ten minutes after we wake up feel like?
280. If we added one recurring thing to our calendar — a class, a walk, a show — what should it be?

## 11. Family, Friends & In-Laws (281–304)

Year three is when the families stop being guests and start being factors.

281. How do you feel about how involved our families are in our lives right now?
282. What boundary with family would you set if it were entirely up to you?
283. What do your parents not know about us that you'd actually be okay with them knowing?
284. Which couple among our friends do you admire, and what do they do well?
285. What friendship of yours has changed since we got together — for better or worse?
286. What holiday tradition from your family do you refuse to lose?
287. What's one tradition you'd happily retire?
288. How do you honestly want to split holidays?
289. What's something your siblings taught you that you still carry?
290. Who would you call at 3am besides me, and what does that friendship give you?
291. What do you think our families misunderstand about us as a couple?
292. What kind of grandparent do you think you'll be someday?
293. What's a story about your family I've never heard in full?
294. How do you want us to handle it when our families disagree about something that matters?
295. What family recipe or ritual do you want to claim for us?
296. Where's your line between loyalty to family and loyalty to each other?
297. Which of my friends do you find the most fun — and which is the most work?
298. If we moved away from family, what would you miss most — and what, honestly, would you not?
299. What friendship do you want to invest more in this year?
300. What did your family model about showing affection — and what did you keep or drop?
301. Whose opinion of us matters most to you, outside our own?
302. What family obligation would you rather turn into a choice?
303. How should we handle money gifts and loans within our families?
304. What do you want to forgive a family member for — and haven't yet?

## 12. Play, Novelty & Adventure (305–332)

Aron's research is blunt: couples who keep doing new things together stay
close. Novelty is not optional at this stage — it's the fuel.

305. What's something new we should try together this month — the weirder the better?
306. What adventure would you plan if I promised to say yes to everything?
307. What's a skill neither of us has that would be hilarious to learn together?
308. What's your ideal adventurous day within an hour of home?
309. What should be our signature couple activity — the thing that's officially "ours"?
310. What game — video, board, or sport — should we make our thing?
311. What type of food have we never cooked together that we should?
312. One free day, zero obligations, $200: what's the play?
313. What's the most spontaneous thing you'd want us to do soon?
314. What city break should we take this year?
315. What's on your "learn to do it" list that I don't know about?
316. What childhood hobby would you pick back up if I joined you?
317. What concert, show, or event do you want us to catch?
318. What activity do you think I'd secretly love if I gave it a real chance?
319. What's the best date we've ever had — and what made it work?
320. What date format have we never tried that you're curious about?
321. What would a perfect no-phones afternoon include for you?
322. What photo or video do we still need to take together?
323. What's something silly you want us to be serious about?
324. What's your favorite way we waste time together?
325. If we entered a competition as a team, what should it be?
326. What tradition from another culture would you love us to adopt just for fun?
327. What rules would you write for our "yes day"?
328. What playlist should exist for us, and what's on it?
329. What's something we laughed about years ago that still makes you laugh?
330. What's the origin story of your favorite inside joke — tell it again?
331. What adventure are you glad we haven't done yet because it's still ahead of us?
332. What do you want us to do for our next big anniversary?

## 13. Growth, Change & Who We're Becoming (333–356)

The person you're with now isn't the person you met. These are how you keep
choosing the current version.

333. How have you changed in the last three years — for better, and where?
334. How have I changed, in your eyes?
335. What part of yourself did you lose touch with that you want back?
336. In what way do you want to grow that has nothing to do with work?
337. What's the best decision you've made since we've been together?
338. What pattern are you trying to break right now?
339. What does "being a good partner" mean to you now, versus when we met?
340. What have you learned about love from being loved by me?
341. What have you learned about yourself from loving me?
342. What would your future self tell you about this exact chapter?
343. What are you tolerating right now that you shouldn't be?
344. What's a fear you've outgrown?
345. What's a fear you're still growing into?
346. What would you tell the version of you from three years ago?
347. What's the most honest feedback I've ever given you — and was it right?
348. What feedback for me have you been sitting on?
349. What does self-care actually look like for you — not the Instagram version?
350. What do you do better now than when we met?
351. What book, podcast, or idea changed your mind recently?
352. Who do you personally know that you genuinely admire — what do they model for you?
353. What do you want your legacy to be at work? In your family? With me?
354. What does rest mean to you — and are you getting any?
355. What would make you feel like this year counted?
356. What's one thing you want us to learn about each other this year?

## 14. Values, Beliefs & Meaning (357–380)

The deep-end-of-the-pool stuff that three years earns you the right to ask.

357. What do you believe happens after we die — and how does that shape how you live?
358. What's a value you'd never compromise, no matter what?
359. What does a meaningful life look like to you?
360. What role does faith, spirituality, or something bigger play for you these days?
361. What's a moral question you've changed your mind on?
362. What makes you angriest about the world — and what do you do with that anger?
363. What gives you hope?
364. If we could only ever donate to one cause, which should it be?
365. What do you think people owe each other?
366. What does success mean to you honestly — not the version you'd say at a party?
367. What belief from your upbringing have you re-examined as an adult?
368. What's the wisest thing anyone has ever told you?
369. What do you want to be known for among the people who know you best?
370. What risk is worth taking even if it fails?
371. What's something true that most people don't want to hear?
372. What do you think the purpose of a relationship actually is?
373. What does loyalty mean beyond fidelity?
374. What's your philosophy on regret?
375. When have you felt most proud to be human?
376. What do you hope stays constant about you no matter what changes?
377. What's a question you wish someone would ask you?
378. What do you think we're here to do — for each other, for anyone?
379. What kind of ancestor do you want to be?
380. What's the difference between happiness and joy for you — and when did you last feel each?

## 15. Just for Fun (381–408)

Because closeness is mostly built out of laughing, not out of seminars.

381. What's the weirdest thing you'd bring to a desert island?
382. Which of us would survive longer in a zombie apocalypse — and why is it you?
383. If we could teleport anywhere for dinner tonight, where are we eating?
384. Which celebrity are we both allowed to fawn over, no jealousy allowed?
385. What's your most useless talent?
386. What's a hill you'll die on even though you know it's ridiculous?
387. If our relationship had a slogan, what would it be?
388. What's the worst movie you love?
389. What would our celebrity couple name be?
390. What's the strangest compliment you've ever given me?
391. If we swapped bodies for a day, what's the first thing you'd do?
392. What food opinion of yours would start a family feud?
393. Superpower pick: teleportation, time-freezing, or reading my mind — choose carefully.
394. What's your dream pet that we'll probably never own?
395. What emoji do you overuse, and what does it say about you?
396. What's your go-to karaoke song — and will you ever actually sing it for me?
397. If we had a band, what would it be called and who plays what?
398. What's the funniest thing you've caught me saying in my sleep, to the dog, or to the microwave?
399. What's your "roman empire" — the random thing you think about way too often?
400. What trend do you secretly love and publicly mock?
401. What would your reality-show archetype be?
402. What conspiracy theory would you subscribe to just for fun?
403. What's the strangest thing in your search history right now?
404. If you had to get a small tattoo related to us, what's the safe and tasteful pick?
405. What's your best grandma-voice life advice? Give it to me right now.
406. Which fictional couple are we most like — and which one must we never become?
407. What's the best worst gift you've ever received?
408. What snack best represents your personality?

## 16. The Deep End (409–432)

Adapted from Arthur Aron's 36 questions — designed to build closeness through
escalating, honest self-disclosure. The twist for a three-year couple: you
think you already know each other's answers. Answer anyway. The answers
change, and noticing *how* they changed is the intimacy.

409. Given the choice of anyone in the world, living or dead, who would you want at dinner — and would I be surprised?
410. Would you want to be famous? In what way?
411. Before making a phone call, do you ever rehearse what you're going to say? Why?
412. What would constitute a perfect day for you — honestly, hour by hour?
413. When did you last sing to yourself? To someone else?
414. If you could live to 90 keeping the mind or the body of a 30-year-old, which would you keep?
415. Name three things we seem to have in common that I might not have noticed.
416. What are you most grateful for right now?
417. If you could change one thing about how you were raised, what would it be?
418. If you could wake up tomorrow having gained one quality or ability, what would it be?
419. If a crystal ball could tell you one truth about your life, what would you want it to say?
420. What's a dream you've had for a long time — and what's actually stopping you?
421. What's your greatest accomplishment so far?
422. What do you value most in a friendship?
423. What's your most treasured memory — and your most terrible one?
424. If you knew you had exactly one year left, what would you change about how we're living?
425. What roles do love and affection play in your everyday life?
426. Make three true "we" statements, each starting "We are both…"
427. Complete this sentence: "I wish I had someone with whom I could share…"
428. Tell me something you like about me that you'd only say this honestly to someone you really knew.
429. When did you last cry in front of another person? By yourself?
430. What, if anything, is too serious to be joked about?
431. If our home caught fire and everyone — and every pet — was safe, what one thing would you run back in for?
432. Share something you're struggling with right now and really let me respond — then tell me what it felt like to be heard.
